function [cap, dbg] = ng_capacity(pile, layers, par)
%NG_CAPACITY Axial pile capacity per NAVFAC DM-7.02 (side + tip + uplift) with debug log.
%
%   [cap, dbg] = ng_capacity(pile, layers, par)
%
%   Method (all coefficients come from par / pile - nothing is hardcoded):
%     side, sand : f = K * sigma_v * tan(delta), delta = Kf*phi;
%                  K = K_down (compression) / K_up (uplift)
%     side, clay : Ca = Kc * Ka * cu (same down/up)
%     sigma_v is CAPPED at the critical depth z_crit = PR * D, for BOTH
%       side friction and tip bearing
%     within z_crit each segment uses the EXACT length-average sigma_v
%       (equals the classic midpoint value unless the water table cuts the
%       segment; dbg sv_within logs the average actually used, mid_within
%       the segment midpoint for reference)
%     tip, sand  : qp = Nq * sigma_v(@min(embed, z_crit)),
%                  Nq from Table 8-1 (ng_nq_table, displacement vs non-)
%     tip, clay  : qp = Nc * cu, Nc from Table 8-2 (ng_nc_table, z/B)
%     optional absolute caps par.f_limit / par.q_limit (NaN = off)
%     uplift     : Qup_ult = Qside_up + W, where W is the BUOYANT weight of
%                  the embedded pile (negative for timber lighter than
%                  water -> reduces uplift capacity)
%     allowable  : down = Qtip/FS_tip + Qside/FS_side
%                  up   = Qside_up/FS_uplift + W/FS_weight
%                  (ALLPILE manual 8.1.1.7: the pile weight carries its own
%                  factor, default 1.0 - NOT Qup_ult/FS_uplift)
%
%   Units: ft, psf, pcf, deg, lb.
%
%   cap : results struct (D, A, P, z_crit, qp, tip_desc, Qside_down,
%         Qside_up, Qtip, W, Qdown_ult, Qup_ult, Qdown_allow, Qup_allow)
%   dbg : debug log - dbg.pile (geometry echo), dbg.par (parameters used),
%         dbg.layers (per-layer record, see template below), dbg.tip,
%         dbg.summary. dbg.layers is what ng_write_csv exports.

    geom = ng_pile_geometry(pile);
    D = geom.D_ft;  A = geom.A_ft2;  P = geom.P_ft;
    WT     = pile.water_table_ft;
    embed  = pile.embedment_ft;
    z_crit = par.PR * D;

    Qs_down = 0;  Qs_up = 0;  current_depth = 0;
    sigma_tip = NaN;  phi_tip = NaN;  cu_tip = NaN;

    % ---- per-layer debug template ----
    tmpl = struct( ...
        'index', NaN, 'depth_top', NaN, 'depth_bot', NaN, ...
        'soil_type', '', 'phi', NaN, 'cu', NaN, ...
        'active', false, 'z1', NaN, 'z2', NaN, ...
        'delta_deg', NaN, 'Ca_psf', NaN, 'K_down', par.K_down, 'K_up', par.K_up, ...
        'within_crit', false, 'L_within', 0, 'mid_within', NaN, 'sv_within', NaN, ...
        'f_down_within', NaN, 'f_up_within', NaN, ...
        'beyond_crit', false, 'L_beyond', 0, 'sv_beyond', NaN, ...
        'f_down_beyond', NaN, 'f_up_beyond', NaN, ...
        'f_limited', false, 'dQs_down', 0, 'dQs_up', 0, ...
        'is_tip_layer', false, 'sigma_tip', NaN, ...
        'Qs_down_running', NaN, 'Qs_up_running', NaN);
    dbg.layers = repmat(tmpl, 1, numel(layers));

    for i = 1:numel(layers)
        lyr = layers(i);  Li = dbg.layers(i);
        Li.index = i;  Li.depth_top = lyr.depth_top;  Li.depth_bot = lyr.depth_bot;
        Li.phi = lyr.phi;  Li.cu = lyr.cu;
        isSand = isfinite(lyr.phi) && lyr.phi > 0;
        if isSand, Li.soil_type = 'sand'; else, Li.soil_type = 'clay'; end

        % overlap of this layer with the embedded shaft
        z1 = max(current_depth, lyr.depth_top);
        z2 = min(embed, lyr.depth_bot);
        if z2 <= z1
            Li.active = false;
            Li.Qs_down_running = Qs_down;  Li.Qs_up_running = Qs_up;
            dbg.layers(i) = Li;
            current_depth = max(current_depth, min(embed, lyr.depth_bot));
            continue;
        end
        Li.active = true;  Li.z1 = z1;  Li.z2 = z2;

        dQsd = 0;  dQsu = 0;
        % ---- segment within critical depth ----
        % sv = EXACT length-average of sigma_v over the segment, computed from
        % the cumulative-integral output of ng_vertical_stress. Identical to
        % midpoint evaluation (the original navfac/ convention) whenever
        % sigma_v is linear across the segment; when the water table cuts the
        % segment, the average is exact where the midpoint overstates it, and
        % the result no longer depends on whether layers are split at the WT.
        if z1 < z_crit
            za = z1;  zb = min(z2, z_crit);  Lw = zb - za;  mid = (za + zb)/2;
            [~, av_b] = ng_vertical_stress(zb, layers, WT);
            [~, av_a] = ng_vertical_stress(za, layers, WT);
            sv = (av_b*zb - av_a*za) / Lw;
            [fd, fu, fin] = ng_unit_side_friction(lyr, sv, par);
            dQsd = dQsd + fd*P*Lw;  dQsu = dQsu + fu*P*Lw;
            Li.within_crit = true;  Li.L_within = Lw;  Li.mid_within = mid;
            Li.sv_within = sv;  Li.f_down_within = fd;  Li.f_up_within = fu;
            Li.delta_deg = fin.delta_deg;  Li.Ca_psf = fin.Ca_psf;
            Li.f_limited = Li.f_limited || fin.f_limited;
        end
        % ---- segment beyond critical depth (sigma_v held at z_crit) ----
        if z2 > z_crit
            za = max(z1, z_crit);  zb = z2;  Lb = zb - za;
            sv = ng_vertical_stress(z_crit, layers, WT);
            [fd, fu, fin] = ng_unit_side_friction(lyr, sv, par);
            dQsd = dQsd + fd*P*Lb;  dQsu = dQsu + fu*P*Lb;
            Li.beyond_crit = true;  Li.L_beyond = Lb;
            Li.sv_beyond = sv;  Li.f_down_beyond = fd;  Li.f_up_beyond = fu;
            Li.delta_deg = fin.delta_deg;  Li.Ca_psf = fin.Ca_psf;
            Li.f_limited = Li.f_limited || fin.f_limited;
        end

        Qs_down = Qs_down + dQsd;  Qs_up = Qs_up + dQsu;
        Li.dQs_down = dQsd;  Li.dQs_up = dQsu;

        % ---- tip layer (tip exactly at an interface -> upper layer governs,
        %      because the lower layer has zero shaft overlap and is skipped
        %      above; same convention as the original packages) ----
        if embed >= lyr.depth_top && embed <= lyr.depth_bot
            Li.is_tip_layer = true;
            sigma_tip = ng_vertical_stress(min(embed, z_crit), layers, WT);
            Li.sigma_tip = sigma_tip;
            if isSand, phi_tip = lyr.phi; cu_tip = NaN;
            else,      cu_tip = lyr.cu;  phi_tip = NaN; end
        end

        Li.Qs_down_running = Qs_down;  Li.Qs_up_running = Qs_up;
        dbg.layers(i) = Li;
        current_depth = z2;
    end

    if ~isfinite(sigma_tip)
        error('navfac_general:tipNotCovered', ...
            'Pile tip depth %.3f ft is not covered by the provided soil layers.', embed);
    end

    % ---- end bearing ----
    Nq = NaN;  Nc = NaN;  z_over_B = embed / D;
    if isfinite(phi_tip) && phi_tip > 0
        Nq = ng_nq_table(phi_tip, pile.pile_type);
        qp_raw = Nq * sigma_tip;
        tip_desc = sprintf('Sand (NAVFAC Nq = %.1f, %s)', Nq, pile.pile_type);
    else
        Nc = ng_nc_table(z_over_B);
        qp_raw = Nc * cu_tip;
        tip_desc = sprintf('Clay (NAVFAC Nc = %.2f at z/B = %.1f)', Nc, z_over_B);
    end
    qp = qp_raw;
    q_limited = false;
    if isfinite(par.q_limit) && qp > par.q_limit
        qp = par.q_limit;  q_limited = true;
        tip_desc = [tip_desc sprintf(' [capped at q_limit = %.0f psf]', par.q_limit)];
    end
    Qtip = A * qp;

    % ---- buoyant weight of the embedded pile ----
    % submerged embedded length = part of the embedment below the water table
    L_sub = max(0, embed - min(WT, embed));
    W = pile.SW * A * embed - pile.gamma_w * A * L_sub;   % [lb], <0 if lighter than water

    % ---- totals ----
    Qdown_ult   = Qtip + Qs_down;
    Qup_ult     = Qs_up + W;
    Qdown_allow = Qtip/par.FS_tip + Qs_down/par.FS_side;
    Qup_allow   = Qs_up/par.FS_uplift + W/par.FS_weight;   % ALLPILE 8.1.1.7

    cap = struct('D', D, 'A', A, 'P', P, 'z_crit', z_crit, ...
        'qp', qp, 'tip_desc', tip_desc, ...
        'Qside_down', Qs_down, 'Qside_up', Qs_up, 'Qtip', Qtip, 'W', W, ...
        'Qdown_ult', Qdown_ult, 'Qup_ult', Qup_ult, ...
        'Qdown_allow', Qdown_allow, 'Qup_allow', Qup_allow);

    dbg.pile = struct('shape', geom.shape, 'size_in', geom.size_in, ...
        'D_ft', D, 'A_ft2', A, 'P_ft', P, 'embedment_ft', embed, ...
        'L_ft', pile.L, 'water_table_ft', WT, 'pile_type', pile.pile_type, ...
        'SW_pcf', pile.SW, 'gamma_w_pcf', pile.gamma_w, 'z_crit_ft', z_crit);
    dbg.par = par;
    dbg.tip = struct('tip_layer_index', find([dbg.layers.is_tip_layer], 1, 'first'), ...
        'phi_tip', phi_tip, 'cu_tip', cu_tip, 'sigma_tip', sigma_tip, ...
        'Nq', Nq, 'Nc', Nc, 'z_over_B', z_over_B, ...
        'qp_raw', qp_raw, 'qp', qp, 'q_limited', q_limited, ...
        'Qtip', Qtip, 'tip_desc', tip_desc);
    dbg.summary = struct('Qside_down', Qs_down, 'Qside_up', Qs_up, ...
        'Qtip', Qtip, 'W', W, 'Qdown_ult', Qdown_ult, 'Qup_ult', Qup_ult, ...
        'Qdown_allow', Qdown_allow, 'Qup_allow', Qup_allow, ...
        'FS_tip', par.FS_tip, 'FS_side', par.FS_side, 'FS_uplift', par.FS_uplift, ...
        'FS_weight', par.FS_weight);
end
