function lt = ng_load_transfer(pile, layers, cap, ves, Q_applied, warn)
%NG_LOAD_TRANSFER Load-settlement relation from t-z / q-w curves (ALLPILE Option 2).
%
%   lt = ng_load_transfer(pile, layers, cap, ves, Q_applied)
%   lt = ng_load_transfer(..., warn)   % warn = false: no warnings (used when
%                                      % this is not the selected method)
%
%   Reproduces ALLPILE 7's "LOAD - TOTAL SETTLEMENT RELATION (from t-z, and
%   q-w curves), Based on Vesic Method" and its work-load settlement. The
%   normalized Reese & O'Neill curves (ng_lt_curves) are scaled by the
%   Vesic settlement at ultimate, then stepped over ALLPILE's 100-point
%   grid u (ng_lt_curves). Verified against all 17 ALLPILE benchmark runs in
%   tests/test_allpile_benchmark.m.
%
%   COMPRESSION table (lt.down), one row per u:
%     Xtip   = u * X_max                         X_max = Xs + Xpp + Xps
%     Qtip   = R_tip(u)  * Qtip_ult
%     Qside  = R_side(u) * Qside_down_ult
%     Xshaft = (Qtip + 0.5*Qside) * Le/(A*E) + (Qtip + Qside) * Lfree/(A*E)
%     Xtop   = Xtip + Xshaft,  Qtotal = Qtip + Qside
%   Side and tip are mobilized at the same normalized step u. The shaft
%   compression in the embedded length uses Vesic's lumped form with
%   xi = 0.5 (uniform side load) - ALLPILE's value, recovered from its
%   tables (it is NOT par.xi). The stick-up Lfree carries the full load.
%
%   UPLIFT table (lt.up), the pile moving as a rigid body:
%     Xtop   = -u * X_up_max                     X_up_max = Xs_up + Xps_up
%     Qside  = R_side(u) * (Qside_up_ult + W)
%     Qtotal = Qside + W                         (uplift positive)
%   NOTE: this is ALLPILE's uplift table exactly as it computes it: the
%   buoyant weight W enters twice (in the mobilized side AND in the total).
%   For piles lighter than water (W < 0, timber) that is conservative and
%   immaterial at work loads. For HEAVY piles (W > 0, e.g. concrete) the
%   table can exceed the ultimate uplift capacity Qup_ult = Qside_up + W;
%   a load above Qup_ult is flagged by ng_settlement_vesic's capacity
%   warning, but the table itself would still report a movement.
%
%   WORK-LOAD settlement: linear interpolation of Xtop against Qtotal at
%   the first crossing of Q_applied, as ALLPILE does. Compression (Q >= 0)
%   interpolates from the origin; uplift (Q < 0) uses the uplift table and
%   returns an upward (negative) movement; an uplift load at or below the
%   first uplift row (only possible when W > 0) moves the pile 0. A load the
%   curve never reaches
%   (the side curve softens, so the curve can peak below Qult) gives NaN
%   and a 'navfac_general:beyondLoadCurve' warning - ALLPILE prints 99999.
%
%   Inputs:  pile (embedment_ft, L, E), layers (for the cohesive check),
%            cap (from ng_capacity: A, Qtip, Qside_down, Qside_up, W),
%            ves (X_max, X_up_max [in], A_in2), Q_applied [lb] (NaN = none).
%   Output:  lt.down, lt.up (tables; forces lb, displacements in),
%            lt.s [in], lt.Kqx [lb/in], lt.mode ('down'|'up'|'none'),
%            lt.row (ALLPILE row number at the upper end of the bracketing
%            segment; 1 = between the origin and row 1),
%            lt.cohesive (true if clay was present - see ng_lt_curves).

    if nargin < 5, Q_applied = NaN; end
    if nargin < 6, warn = true; end
    [u, R_tip, R_side] = ng_lt_curves();

    AE    = ves.A_in2 * pile.E;                    % [lb]
    Le    = pile.embedment_ft * 12;                % [in]
    Lfree = max(pile.L - pile.embedment_ft, 0) * 12;

    % ---- cohesive soil present? (curves are cohesionless-only) ----
    cohesive = false;
    for i = 1:numel(layers)
        if layers(i).depth_top < pile.embedment_ft && ~(isfinite(layers(i).phi) && layers(i).phi > 0)
            cohesive = true;
        end
    end

    % ---- compression table ----
    d.u      = u;
    d.Qtip   = R_tip  * cap.Qtip;
    d.Qside  = R_side * cap.Qside_down;
    d.Qtotal = d.Qtip + d.Qside;
    d.Xtip   = u * ves.X_max;
    d.Xshaft = (d.Qtip + 0.5 * d.Qside) * Le / AE + d.Qtotal * Lfree / AE;
    d.Xtop   = d.Xtip + d.Xshaft;

    % ---- uplift table (rigid; ALLPILE counts W in the side and the total) ----
    up.u      = u;
    up.Weight = cap.W * ones(size(u));
    up.Qside  = R_side * (cap.Qside_up + cap.W);
    up.Qtotal = up.Qside + up.Weight;
    up.Xtop   = -u * ves.X_up_max;

    lt = struct('down', d, 'up', up, 's', NaN, 'Kqx', NaN, 'mode', 'none', ...
        'row', NaN, 'cohesive', cohesive);

    if ~isfinite(Q_applied), return; end

    if Q_applied >= 0
        lt.mode = 'down';
        [lt.s, lt.row] = first_crossing([0; d.Qtotal], [0; d.Xtop], Q_applied);
        curve_max = max(d.Qtotal);
    else
        lt.mode = 'up';
        if -Q_applied <= up.Qtotal(1)
            % a heavy pile (W > 0) carries this much uplift on its own weight
            lt.s = 0;  lt.row = 1;
        else
            [lt.s, lt.row] = first_crossing(up.Qtotal, up.Xtop, -Q_applied);
            lt.row = lt.row + 1;           % uplift table has no origin row
        end
        curve_max = max(up.Qtotal);
    end

    if ~isnan(lt.s) && lt.s ~= 0
        lt.Kqx = Q_applied / lt.s;         % secant stiffness [lb/in], as ALLPILE
    end
    if ~warn, return; end
    if isnan(lt.s)
        warning('navfac_general:beyondLoadCurve', ...
            ['|Q_applied| = %.2f k exceeds the peak of the %s load-settlement ' ...
             'curve (%.2f k): no settlement solution (ALLPILE reports 99999).'], ...
            abs(Q_applied) / 1000, ifelse(Q_applied >= 0, 'compression', 'uplift'), ...
            curve_max / 1000);
    end
    if cohesive
        warning('navfac_general:ltCohesive', ...
            ['Clay is present along the pile: the load-transfer settlement uses the ' ...
             'cohesionless Reese & O''Neill curves (ALLPILE uses separate cohesive ' ...
             'curves, Figs 8-2/8-4, which are not included). Treat s_applied as approximate.']);
    end
end

function [x, row] = first_crossing(Q, X, q)
% Linear interpolation of X at the first segment where Q passes through q.
    x = NaN; row = NaN;
    for i = 2:numel(Q)
        if (Q(i - 1) - q) * (Q(i) - q) <= 0 && Q(i) ~= Q(i - 1)
            t = (q - Q(i - 1)) / (Q(i) - Q(i - 1));
            x = X(i - 1) + t * (X(i) - X(i - 1));
            row = i - 1;
            return
        end
    end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
