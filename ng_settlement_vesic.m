function st = ng_settlement_vesic(pile, layers, par, cap, Q_applied)
%NG_SETTLEMENT_VESIC Vesic (1977) settlement at ultimate + settlement at the applied load.
%
%   st = ng_settlement_vesic(pile, layers, par, cap, Q_applied)
%
%   1. X_max - Vesic settlement at ULTIMATE resistance (an UPPER BOUND, not
%      the service settlement). Matches ALLPILE's "SETTLEMENT based on
%      Ultimate Loading by Vesic Method" to every printed digit on the
%      benchmark:
%        X_max = Xs + Xpp + Xps   [in]
%        Xs  : elastic shortening of the pile - stick-up carries the full
%              ultimate load; below grade the axial force decays with the
%              side friction shed above each slice (slice integration,
%              thickness par.settle_dz)
%        Xpp : settlement from load at the tip   = Cp*Qtip/(D*qp)
%        Xps : settlement from shaft load        = Cs*Qside/(Le*qp),
%              Cs = (0.93 + 0.16*sqrt(Le/D))*Cp,  Le = embedment
%      The UPLIFT counterpart X_up_max = Xs_up + Xps_up (no tip term; Xs_up
%      integrates the tension = uplift side resistance below + buoyant
%      pile weight below; Xps_up uses Qside_up) scales the uplift
%      load-settlement table, as in ALLPILE.
%
%   2. s_applied - settlement under the applied load Q_applied [lb]
%      (compression > 0, UPLIFT < 0, 0 allowed; NaN/absent skips the block),
%      by par.settle_method:
%
%      'allpile' (default) - ALLPILE 7's load-settlement relation from the
%         Reese & O'Neill t-z / q-w curves scaled by the Vesic settlement
%         ('Option 2'), linearly interpolated at Q_applied. See
%         ng_load_transfer. Handles compression and uplift. Reproduces
%         ALLPILE's work-load settlement on all 17 benchmark runs
%         (tests/test_allpile_benchmark.m). Upward movement is negative.
%
%      'vesic_linear' - the earlier linear Vesic estimate, compression only
%         (NaN for uplift). The load is split SHAFT-FIRST:
%           Qws = min(Q, Qside) ,  Qwp = Q - Qws
%           s1 (shaft shortening) = (Qwp + xi*Qws)*L /(Ap*Ep)   [xi = par.xi]
%           s2 (point)            = Cp*Qwp/(D*qp)
%           s3 (shaft transfer)   = Cs*Qws/(Le*qp)
%           s_vesic_linear = s1 + s2 + s3
%         For any Q <= Qside the tip term s2 is exactly zero. It runs
%         11-17% above ALLPILE on the benchmark.
%
%      BOTH are always computed (where defined): st.s_allpile and
%      st.s_vesic_linear; st.s_applied is the selected one. Only the
%      selected method raises its warnings.
%
%   Cp = par.Cp, or - when par.Cp is NaN - looked up automatically from
%   ng_cp_table using the TIP soil type and pile.pile_type (Table 8-3).
%
%   st fields: Xs, Xpp, Xps, Xtotal, Xmax (= Xtotal) [in]; Xs_up, Xps_up,
%   X_up_max [in]; Cp, cp_source, Cs, xi, qp_psf, n_slices; lt (load-
%   settlement tables, see ng_load_transfer); and (applied load)
%   has_applied, Q_applied, ratio (|Q| / ultimate capacity in the load's
%   direction), settle_method, s_applied, s_allpile, s_vesic_linear,
%   Kqx [lb/in, secant Q/s], lt_mode, lt_row, and the vesic_linear
%   components Qwp, Qws, s1, s2, s3. Applied-load fields are NaN when
%   there is no applied load.

    if nargin < 5, Q_applied = NaN; end

    A_in2 = cap.A * 144;          % [in^2]
    E     = pile.E;               % [psi]
    AE    = A_in2 * E;            % [lb]
    D_in  = pile.size_in;         % [in]
    embed = pile.embedment_ft;    % [ft]  (= Le, the load-transfer length)
    stickup = max(pile.L - embed, 0);
    P  = cap.P;                   % [ft]
    A  = cap.A;                   % [ft^2]
    WT = pile.water_table_ft;
    z_crit = cap.z_crit;
    Qtip = cap.Qtip;  Qside = cap.Qside_down;  Qult = cap.Qdown_ult;
    Qs_up = cap.Qside_up;  W = cap.W;  Qup_ult = cap.Qup_ult;
    qp_psi = cap.qp / 144;        % [psi]  q_p = Qtip/Ap (ultimate unit tip pressure)

    xi = par.xi;

    % ---- Cp: explicit value, or auto from Table 8-3 (tip soil + pile type)
    Cp = par.Cp;
    cp_source = 'par.Cp (user)';
    if ~isfinite(Cp)
        tip_soil = tip_soil_type(layers, embed);
        Cp = ng_cp_table(tip_soil, pile.pile_type);
        cp_source = sprintf('ng_cp_table(%s, %s)', tip_soil, pile.pile_type);
    end
    Cs = (0.93 + 0.16 * sqrt(embed / cap.D)) * Cp;

    % =============== 1. X_max: Vesic settlement at ULTIMATE ===============
    % ---- X_s (compression) and Xs_up (uplift): slice integration ----
    Xs    = Qult * (stickup * 12) / AE;        % stick-up at full Qult
    Xs_up = (Qs_up + W) * (stickup * 12) / AE; % stick-up at full uplift tension
    n = max(1, round(embed / par.settle_dz));
    step = embed / n;
    side_above = 0;  side_up_above = 0;  w_above = 0;
    for i = 1:n
        zc = (i - 0.5) * step;
        N    = Qtip + (Qside - side_above);             % compression in this slice
        N_up = (Qs_up - side_up_above) + (W - w_above); % uplift tension in this slice
        Xs    = Xs    + N    * (step * 12) / AE;
        Xs_up = Xs_up + N_up * (step * 12) / AE;
        sv = ng_vertical_stress(min(zc, z_crit), layers, WT);
        lyr = layers(ng_layer_at(zc, layers));
        [f_dn, f_up] = ng_unit_side_friction(lyr, sv, par);
        side_above    = side_above    + f_dn * P * step;
        side_up_above = side_up_above + f_up * P * step;
        w_above = w_above + (pile.SW - pile.gamma_w * (zc > WT)) * A * step;  % buoyant below WT
    end
    Xpp = Cp * Qtip / (D_in * qp_psi);                  % ---- X_pp: tip ----
    Xps = Cs * Qside / ((embed * 12) * qp_psi);         % ---- X_ps: shaft ----
    Xmax = Xs + Xpp + Xps;
    Xps_up = Cs * Qs_up / ((embed * 12) * qp_psi);      % uplift: shaft only
    X_up_max = Xs_up + Xps_up;

    % =============== 2. settlement at the applied load ==========
    method = par.settle_method;
    has_applied = isfinite(Q_applied);
    Qwp = NaN; Qws = NaN; s1 = NaN; s2 = NaN; s3 = NaN;
    s_vl = NaN; ratio = NaN; Kqx = NaN;
    if has_applied
        if Q_applied >= 0
            ratio = Q_applied / Qult;          % utilization, reported for reference
            if Q_applied >= Qult
                warning('navfac_general:loadExceedsCapacity', ...
                    ['Q_applied = %.1f lb (%.2f k) >= ultimate downward capacity ' ...
                     '%.1f lb (%.2f k): the pile is overloaded (Q/Qult = %.2f).'], ...
                    Q_applied, Q_applied/1000, Qult, Qult/1000, ratio);
            end
            % ---- 'vesic_linear': shaft-first split ----
            % Side friction mobilizes at a much smaller displacement than end
            % bearing, so the shaft carries the load up to its ultimate side
            % resistance and only the excess reaches the tip. For Q <= Qside
            % this leaves Qwp - and therefore the point term s2 - exactly zero.
            Qws = min(Q_applied, Qside);
            Qwp = Q_applied - Qws;
            s1 = (Qwp + xi * Qws) * (pile.L * 12) / AE;        % shaft shortening
            s2 = Cp * Qwp / (D_in * qp_psi);                   % point
            s3 = Cs * Qws / ((embed * 12) * qp_psi);           % shaft transfer
            s_vl = s1 + s2 + s3;
        else
            if Qup_ult > 0, ratio = -Q_applied / Qup_ult; end
            if Qup_ult <= 0 || -Q_applied >= Qup_ult
                warning('navfac_general:loadExceedsCapacity', ...
                    ['Uplift Q_applied = %.1f lb (%.2f k) >= ultimate uplift capacity ' ...
                     '%.1f lb (%.2f k): the pile is overloaded in uplift.'], ...
                    -Q_applied, -Q_applied/1000, Qup_ult, Qup_ult/1000);
            end
            if strcmp(method, 'vesic_linear')
                warning('navfac_general:vesicLinearUplift', ...
                    ['settle_method ''vesic_linear'' is compression-only: s_applied is NaN ' ...
                     'for an uplift load. Use ''allpile'' for uplift movement.']);
            end
        end
    end

    % ---- 'allpile': load-transfer table (always built; warns only if selected)
    ves = struct('X_max', Xmax, 'X_up_max', X_up_max, 'A_in2', A_in2);
    lt = ng_load_transfer(pile, layers, cap, ves, Q_applied, strcmp(method, 'allpile'));

    if strcmp(method, 'allpile')
        s_applied = lt.s;  Kqx = lt.Kqx;
    else
        s_applied = s_vl;
        if isfinite(s_vl) && s_vl ~= 0, Kqx = Q_applied / s_vl; end
    end

    st = struct('Xs', Xs, 'Xpp', Xpp, 'Xps', Xps, 'Xtotal', Xmax, 'Xmax', Xmax, ...
        'Xs_up', Xs_up, 'Xps_up', Xps_up, 'X_up_max', X_up_max, ...
        'Cp', Cp, 'cp_source', cp_source, 'Cs', Cs, 'xi', xi, ...
        'qp_psf', cap.qp, 'n_slices', n, ...
        'has_applied', has_applied, 'Q_applied', Q_applied, 'ratio', ratio, ...
        'settle_method', method, 's_applied', s_applied, ...
        's_allpile', lt.s, 's_vesic_linear', s_vl, 'Kqx', Kqx, ...
        'lt_mode', lt.mode, 'lt_row', lt.row, ...
        'Qwp', Qwp, 'Qws', Qws, 's1', s1, 's2', s2, 's3', s3);
    st.lt = struct('down', lt.down, 'up', lt.up, 'cohesive', lt.cohesive);
end

function t = tip_soil_type(layers, embed)
    lyr = layers(ng_layer_at(embed, layers));
    if isfinite(lyr.phi) && lyr.phi > 0, t = 'sand'; else, t = 'clay'; end
end
