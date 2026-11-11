function inp = ng_validate_input(inp)
%NG_VALIDATE_INPUT Validate a fully-defaulted case input; error with clear messages.
%
%   inp = ng_validate_input(inp)   (call AFTER ng_apply_defaults)
%
%   Checks
%     pile  : shape round|square; size_in>0; embedment_ft>0; L>=embedment;
%             E>0; SW>0; gamma_w>0; water_table_ft>=0; pile_type valid.
%     par   : positive coefficients, FS>=1 (incl. FS_weight), PR>0, xi>0
%             (range warning), settle_method 'allpile'|'vesic_linear'.
%     layers: non-empty; required fields; depth_bot>depth_top; first layer
%             starts at 0; contiguous (no gaps/overlaps); gammas>0; each
%             layer sand (phi>0) XOR clay (cu>0) - both or neither errors;
%             embedment covered by the layer stack.
%     Q_applied (top-level, optional): finite [lb] (compression > 0, uplift
%             < 0, zero allowed), or NaN/absent.
%
%   Units: depths/lengths ft, unit weights pcf, phi deg, cu psf, E psi.

    % ---------------- pile ----------------
    p = require_fields(inp, 'pile', {'shape','size_in','embedment_ft','L','E','SW'});

    if ~(ischar(p.shape) && any(strcmpi(p.shape, {'round','square'})))
        error('navfac_general:badShape', ...
            'pile.shape must be ''round'' or ''square'' (got "%s").', tostr(p.shape));
    end
    check_pos(p.size_in,      'pile.size_in [in]');
    check_pos(p.embedment_ft, 'pile.embedment_ft [ft]');
    check_pos(p.L,            'pile.L [ft]');
    check_pos(p.E,            'pile.E [psi]');
    check_pos(p.SW,           'pile.SW [pcf]');
    check_pos(p.gamma_w,      'pile.gamma_w [pcf]');
    if ~(isnumeric(p.water_table_ft) && isscalar(p.water_table_ft) && ...
            isfinite(p.water_table_ft) && p.water_table_ft >= 0)
        error('navfac_general:badWaterTable', ...
            'pile.water_table_ft must be a finite number >= 0 (depth below surface; 0 = at/above surface).');
    end
    if p.L < p.embedment_ft
        error('navfac_general:badLength', ...
            'pile.L = %.2f ft is shorter than pile.embedment_ft = %.2f ft.', p.L, p.embedment_ft);
    end
    if ~(ischar(p.pile_type) && any(strcmp(p.pile_type, {'displacement','nondisplacement'})))
        error('navfac_general:badPileType', ...
            'pile.pile_type must be ''displacement'' (driven) or ''nondisplacement'' (bored), got "%s".', ...
            tostr(p.pile_type));
    end

    % ---------------- par ----------------
    a = inp.par;
    check_pos(a.K_down, 'par.K_down'); check_pos(a.K_up, 'par.K_up');
    check_pos(a.Kf, 'par.Kf');         check_pos(a.Kc, 'par.Kc');
    check_pos(a.Ka, 'par.Ka');         check_pos(a.PR, 'par.PR');
    check_pos(a.settle_dz, 'par.settle_dz [ft]');
    check_pos(a.xi, 'par.xi');
    if a.xi < 0.5 || a.xi > 0.67
        warning('navfac_general:xiRange', ...
            'par.xi = %.3g is outside the usual Vesic range 0.5 - 0.67.', a.xi);
    end
    fs = {'FS_tip','FS_side','FS_uplift','FS_weight'};
    for i = 1:numel(fs)
        v = a.(fs{i});
        if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v >= 1)
            error('navfac_general:badFS', 'par.%s must be a finite number >= 1.', fs{i});
        end
    end
    % f_limit/q_limit/Cp/Q_work: NaN allowed (= off / auto); else must be > 0
    check_pos_or_nan(a.f_limit, 'par.f_limit [psf]');
    check_pos_or_nan(a.q_limit, 'par.q_limit [psf]');
    check_pos_or_nan(a.Cp,      'par.Cp');
    if a.Kf > 1
        warning('navfac_general:KfHigh', ...
            'par.Kf = %.2f gives delta > phi; NAVFAC uses delta <= phi (Kf <= 1).', a.Kf);
    end
    if ~(ischar(a.settle_method) && any(strcmp(a.settle_method, {'allpile','vesic_linear'})))
        error('navfac_general:badSettleMethod', ...
            'par.settle_method must be ''allpile'' or ''vesic_linear'' (got "%s").', ...
            tostr(a.settle_method));
    end

    % ---------------- applied load (top-level, optional) ----------------
    % NaN/absent = skip the applied-load settlement. A value must be finite
    % [lb], ALLPILE's sign convention: COMPRESSION > 0, UPLIFT < 0. Zero is
    % allowed and is NOT the same as absent: the applied-load block still
    % runs and reports s_applied = 0 (useful as a baseline / no-load check).
    if isfield(inp, 'Q_applied') && ~isempty(inp.Q_applied) && ~all(isnan(inp.Q_applied(:)))
        q = inp.Q_applied;
        if ~(isnumeric(q) && isscalar(q) && isfinite(q))
            error('navfac_general:badQapplied', ...
                ['inp.Q_applied must be a finite load [lb] (compression > 0, ' ...
                 'uplift < 0), or NaN/absent to skip the applied-load settlement.']);
        end
    end

    % ---------------- layers ----------------
    if ~isfield(inp, 'layers') || isempty(inp.layers)
        error('navfac_general:noLayers', 'inp.layers must contain at least one soil layer.');
    end
    L = inp.layers;
    req = {'depth_top','depth_bot','gamma_above','gamma_below','phi','cu'};
    for i = 1:numel(L)
        for j = 1:numel(req)
            if ~isfield(L(i), req{j})
                error('navfac_general:layerField', ...
                    'Layer %d is missing required field "%s".', i, req{j});
            end
        end
        if ~(L(i).depth_bot > L(i).depth_top)
            error('navfac_general:layerDepths', ...
                'Layer %d: depth_bot (%.3f) must exceed depth_top (%.3f) [ft].', ...
                i, L(i).depth_bot, L(i).depth_top);
        end
        check_pos(L(i).gamma_above, sprintf('layers(%d).gamma_above [pcf]', i));
        check_pos(L(i).gamma_below, sprintf('layers(%d).gamma_below [pcf]', i));
        if L(i).gamma_below >= L(i).gamma_above
            warning('navfac_general:gammaOrder', ...
                ['Layer %d: gamma_below (buoyant, %.0f pcf) >= gamma_above (total, %.0f pcf). ' ...
                 'gamma_below should normally be the buoyant unit weight (total - 62.4).'], ...
                i, L(i).gamma_below, L(i).gamma_above);
        end

        % optional per-layer interface-angle override (sand only;
        % [] or NaN = no override)
        if isfield(L(i), 'delta_deg') && ~isempty(L(i).delta_deg)
            d = L(i).delta_deg;
            if ~(isnumeric(d) && isscalar(d))
                error('navfac_general:badDelta', ...
                    'Layer %d: delta_deg must be a numeric scalar (NaN = no override).', i);
            end
            if isfinite(d)
                if ~(d > 0 && d < 90)
                    error('navfac_general:badDelta', ...
                        'Layer %d: delta_deg must be in (0, 90) deg when set (got %.3g).', i, d);
                end
                if ~(isfinite(L(i).phi) && L(i).phi > 0)
                    warning('navfac_general:deltaOnClay', ...
                        'Layer %d: delta_deg is set but the layer is clay - it will be ignored.', i);
                end
            end
        end

        % sand XOR clay
        phi_ok = isfinite(L(i).phi) && L(i).phi > 0;
        cu_ok  = isfinite(L(i).cu)  && L(i).cu  > 0;
        if phi_ok && cu_ok
            error('navfac_general:bothPhiCu', ...
                ['Layer %d has BOTH phi (%.3g deg) and cu (%.3g psf) set. ' ...
                 'Each layer must be sand (phi>0, cu=NaN) XOR clay (cu>0, phi=NaN).'], ...
                i, L(i).phi, L(i).cu);
        elseif ~phi_ok && ~cu_ok
            error('navfac_general:neitherPhiCu', ...
                ['Layer %d has neither a valid phi nor a valid cu. ' ...
                 'Provide phi>0 [deg] (sand) OR cu>0 [psf] (clay); set the other to NaN.'], i);
        end
    end

    % contiguity from the surface
    tol = 1e-9;
    if abs(L(1).depth_top) > tol
        error('navfac_general:layersStart', ...
            'layers(1).depth_top must be 0 (ground surface/mudline), got %.3f ft.', L(1).depth_top);
    end
    for i = 2:numel(L)
        gap = L(i).depth_top - L(i-1).depth_bot;
        if gap > tol
            error('navfac_general:layerGap', ...
                'Gap of %.3f ft between layer %d (bottom %.3f ft) and layer %d (top %.3f ft).', ...
                gap, i-1, L(i-1).depth_bot, i, L(i).depth_top);
        elseif gap < -tol
            error('navfac_general:layerOverlap', ...
                'Layer %d (top %.3f ft) overlaps layer %d (bottom %.3f ft) by %.3f ft.', ...
                i, L(i).depth_top, i-1, L(i-1).depth_bot, -gap);
        end
    end

    % embedment coverage
    bottom = L(end).depth_bot;
    if p.embedment_ft > bottom + tol
        error('navfac_general:tipNotCovered', ...
            ['Pile embedment %.2f ft is below the bottom of the deepest soil layer (%.2f ft). ' ...
             'Extend the layer stack to cover the pile tip.'], p.embedment_ft, bottom);
    end
end

% ---------------------------------------------------------------- helpers
function s = require_fields(inp, name, req)
    if ~isfield(inp, name)
        error('navfac_general:missingStruct', 'Input is missing the "%s" struct.', name);
    end
    s = inp.(name);
    for j = 1:numel(req)
        if ~isfield(s, req{j}) || isempty(s.(req{j}))
            error('navfac_general:missingField', ...
                'inp.%s.%s is required (see inputs/input_template.m for units).', name, req{j});
        end
    end
end

function check_pos(v, label)
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v > 0)
        error('navfac_general:notPositive', '%s must be a finite number > 0.', label);
    end
end

function check_pos_or_nan(v, label)
    if ~(isnumeric(v) && isscalar(v) && (isnan(v) || (isfinite(v) && v > 0)))
        error('navfac_general:notPositiveOrNaN', ...
            '%s must be a finite number > 0, or NaN to disable/auto-select.', label);
    end
end

function s = tostr(v)
    if ischar(v), s = v; else, s = class(v); end
end
