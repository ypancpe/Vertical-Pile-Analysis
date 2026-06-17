function st = ng_settlement_vesic(pile, layers, par, cap, Q_applied)
%NG_SETTLEMENT_VESIC Vesic (1977) settlement: ultimate UPPER BOUND + applied-load.
%
%   st = ng_settlement_vesic(pile, layers, par, cap, Q_applied)
%
%   Returns TWO settlements (the applied-load one only when Q_applied is given):
%
%   1. X_max - MAXIMUM settlement, at ULTIMATE resistance. This is an UPPER
%      BOUND (the most that could occur), NOT the settlement under the
%      service load. Unchanged from the original calc:
%        X_max = Xs + Xpp + Xps   [in]
%        Xs  : elastic shortening of the pile - stick-up carries the full
%              ultimate load; below grade the axial force decays with the
%              side friction shed above each slice (slice integration,
%              thickness par.settle_dz)
%        Xpp : settlement from load at the tip   = Cp*Qtip/(D*qp)
%        Xps : settlement from shaft load        = Cs*Qside/(Le*qp),
%              Cs = (0.93 + 0.16*sqrt(Le/D))*Cp,  Le = embedment
%
%   2. s_applied - settlement under the applied COMPRESSION load Q_applied
%      [lb], computed ONLY when Q_applied is finite and > 0 (otherwise this
%      block is skipped and its fields are NaN). The applied load is split
%      between tip and shaft in proportion to their ULTIMATE downward
%      resistances - a simplification that assumes tip and shaft mobilize
%      proportionally:
%        Qwp = Q*(Qtip/Qult) ,  Qws = Q*(Qside/Qult)
%        s1 (shaft shortening) = (Qwp + xi*Qws)*L /(Ap*Ep)   [xi = par.xi]
%        s2 (point)            = Cp*Qwp/(D*qp)
%        s3 (shaft transfer)   = Cs*Qws/(Le*qp)
%        s_applied = s1 + s2 + s3
%      q_p is the SAME ultimate unit end-bearing pressure used for X_max
%      (q_p = Qtip/Ap = cap.qp). s2 and s3 are exactly Xpp and Xps scaled by
%      Q/Qult; s1 uses the lumped Das (Eq. 11.73) elastic-shortening form
%      over the TOTAL pile length L, so it counts the stick-up like Xs does.
%
%   Cp = par.Cp, or - when par.Cp is NaN - looked up automatically from
%   ng_cp_table using the TIP soil type and pile.pile_type (Table 8-3).
%
%   NOTE s_applied is a Vesic LINEAR-ELASTIC estimate (applied load split
%   tip/shaft by the ultimate-resistance ratio). ALLPILE's reported
%   working-load settlement uses nonlinear Reese-O'Neill t-z/q-w transfer
%   curves, so the two will not match exactly. X_max is the bound at full
%   ultimate resistance, NOT the service settlement.
%
%   st fields: Xs, Xpp, Xps, Xtotal, Xmax (= Xtotal) [in]; Cp, cp_source,
%   Cs, xi, qp_psf, n_slices; and (applied-load) has_applied, Q_applied,
%   ratio, Qwp, Qws, s1, s2, s3, s_applied (all NaN when no applied load).

    if nargin < 5, Q_applied = NaN; end

    A_in2 = cap.A * 144;          % [in^2]
    E     = pile.E;               % [psi]
    D_in  = pile.size_in;         % [in]
    embed = pile.embedment_ft;    % [ft]  (= Le, the load-transfer length)
    stickup = max(pile.L - embed, 0);
    P  = cap.P;                   % [ft]
    WT = pile.water_table_ft;
    z_crit = cap.z_crit;
    Qtip = cap.Qtip;  Qside = cap.Qside_down;  Qult = cap.Qdown_ult;
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

    % =============== 1. X_max: MAXIMUM settlement at ULTIMATE ===============
    % ---- X_s: axial shortening (slice integration, ultimate load) ----
    Xs = Qult * (stickup * 12) / (A_in2 * E);   % stick-up at full Qult
    n = max(1, round(embed / par.settle_dz));
    step = embed / n;
    side_above = 0;
    for i = 1:n
        zc = (i - 0.5) * step;
        N = Qtip + (Qside - side_above);        % axial force in this slice
        Xs = Xs + N * (step * 12) / (A_in2 * E);
        sv = ng_vertical_stress(min(zc, z_crit), layers, WT);
        lyr = layers(ng_layer_at(zc, layers));
        f = ng_unit_side_friction(lyr, sv, par);     % f_down
        side_above = side_above + f * P * step;
    end
    Xpp = Cp * Qtip / (D_in * qp_psi);                  % ---- X_pp: tip ----
    Xps = Cs * Qside / ((embed * 12) * qp_psi);         % ---- X_ps: shaft ----
    Xmax = Xs + Xpp + Xps;

    % =============== 2. s_applied: settlement at the applied load ==========
    has_applied = isfinite(Q_applied) && Q_applied > 0;
    Qwp = NaN; Qws = NaN; s1 = NaN; s2 = NaN; s3 = NaN; s_applied = NaN; ratio = NaN;
    if has_applied
        if Q_applied >= Qult
            warning('navfac_general:loadExceedsCapacity', ...
                ['Q_applied = %.1f lb (%.2f k) >= ultimate downward capacity ' ...
                 '%.1f lb (%.2f k). Settlement still reported, but the pile is ' ...
                 'overloaded (Q/Qult = %.2f).'], ...
                Q_applied, Q_applied/1000, Qult, Qult/1000, Q_applied/Qult);
        end
        ratio = Q_applied / Qult;
        Qwp = Q_applied * (Qtip  / Qult);     % tip share (proportional split)
        Qws = Q_applied * (Qside  / Qult);     % shaft share
        s1 = (Qwp + xi * Qws) * (pile.L * 12) / (A_in2 * E);   % shaft shortening
        s2 = Cp * Qwp / (D_in * qp_psi);                       % point
        s3 = Cs * Qws / ((embed * 12) * qp_psi);               % shaft transfer
        s_applied = s1 + s2 + s3;
    end

    st = struct('Xs', Xs, 'Xpp', Xpp, 'Xps', Xps, 'Xtotal', Xmax, 'Xmax', Xmax, ...
        'Cp', Cp, 'cp_source', cp_source, 'Cs', Cs, 'xi', xi, ...
        'qp_psf', cap.qp, 'n_slices', n, ...
        'has_applied', has_applied, 'Q_applied', Q_applied, 'ratio', ratio, ...
        'Qwp', Qwp, 'Qws', Qws, 's1', s1, 's2', s2, 's3', s3, 's_applied', s_applied);
end

function t = tip_soil_type(layers, embed)
    lyr = layers(ng_layer_at(embed, layers));
    if isfinite(lyr.phi) && lyr.phi > 0, t = 'sand'; else, t = 'clay'; end
end
