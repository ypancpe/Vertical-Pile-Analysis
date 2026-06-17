function ng_print_results(inp, cap, st, dbg)
%NG_PRINT_RESULTS Console summary + optional per-layer debug table.
%
%   ng_print_results(inp, cap, st, dbg)
%
%   Controlled by inp.opts: verbose (summary block), print_layers
%   (per-layer side-friction table). Forces are printed in kips, unit
%   resistances in ksf, settlement in inches.

    o = inp.opts;
    k = @(x) x / 1000;

    if o.verbose
        fprintf('============================================================\n');
        fprintf('CASE: %s\n', inp.case_name);
        fprintf('============================================================\n');
        fprintf('Pile: %s %.3g in, embedment %.2f ft of %.2f ft total, %s\n', ...
            dbg.pile.shape, dbg.pile.size_in, dbg.pile.embedment_ft, ...
            dbg.pile.L_ft, dbg.pile.pile_type);
        fprintf('D = %.3f ft   A = %.4f ft^2   Perim = %.4f ft   z_crit (%.0fD) = %.2f ft\n', ...
            cap.D, cap.A, cap.P, inp.par.PR, cap.z_crit);
        fprintf('Water table: %.2f ft below surface\n', dbg.pile.water_table_ft);
        fprintf('Tip method: %s;  qp = %.2f ksf\n', cap.tip_desc, k(cap.qp));
        fprintf('------------------------------------------------------------\n');
        fprintf('--- DOWNWARD (compression) ---\n');
        fprintf('  Side resistance (down) : %8.3f kips\n', k(cap.Qside_down));
        fprintf('  Tip resistance         : %8.3f kips\n', k(cap.Qtip));
        fprintf('  Total ultimate (down)  : %8.3f kips\n', k(cap.Qdown_ult));
        fprintf('  Total allowable (down) : %8.3f kips  (FS_tip = %.1f, FS_side = %.1f)\n', ...
            k(cap.Qdown_allow), inp.par.FS_tip, inp.par.FS_side);
        fprintf('--- UPLIFT ---\n');
        fprintf('  Side resistance (up)   : %8.3f kips\n', k(cap.Qside_up));
        fprintf('  Buoyant pile weight W  : %8.3f kips\n', k(cap.W));
        fprintf('  Total ultimate (up)    : %8.3f kips\n', k(cap.Qup_ult));
        fprintf('  Total allowable (up)   : %8.3f kips  (FS = %.1f)\n', ...
            k(cap.Qup_allow), inp.par.FS_uplift);
        if ~isempty(st)
            fprintf('--- SETTLEMENT (Vesic 1977) ---\n');
            fprintf('  Maximum settlement (at ULTIMATE capacity - upper bound):\n');
            fprintf('    Xs(shaft)=%.4f in   Xpp(point)=%.4f in   Xps(transfer)=%.4f in   X_max=%.4f in\n', ...
                st.Xs, st.Xpp, st.Xps, st.Xmax);
            if st.has_applied
                fprintf('  Settlement at applied load Q=%.3f k  (Q/Qult=%.3f):\n', ...
                    k(st.Q_applied), st.ratio);
                fprintf('    s_shaft=%.4f in   s_point=%.4f in   s_transfer=%.4f in   s_applied=%.4f in\n', ...
                    st.s1, st.s2, st.s3, st.s_applied);
                fprintf('    [load split: tip Qwp=%.3f k, shaft Qws=%.3f k]\n', ...
                    k(st.Qwp), k(st.Qws));
                if st.ratio >= 1
                    fprintf('    WARNING: applied load >= ultimate capacity (pile overloaded).\n');
                end
            else
                fprintf('  Settlement at applied load: not computed (set inp.Q_applied [lb] to enable).\n');
            end
            fprintf('  Cp=%.3f (%s);  xi=%.2f\n', st.Cp, st.cp_source, st.xi);
            fprintf('  NOTE: X_max is the bound at full ultimate resistance, NOT the service settlement.\n');
            if st.has_applied
                fprintf('  NOTE: s_applied is a Vesic linear-elastic estimate; ALLPILE''s nonlinear\n');
                fprintf('        Reese-O''Neill (t-z/q-w) working-load settlement will differ.\n');
            end
        end
    end

    if o.print_layers
        fprintf('\n--- DEBUG: per-layer side resistance ---\n');
        fprintf('%3s %6s %6s %5s %5s %7s %8s %7s %8s %8s %9s %9s %9s\n', ...
            'lyr', 'z1', 'z2', 'type', 'phi', 'cu', 'sv_mid', 'delta', ...
            'f_dn', 'f_up', 'dQs_dn', 'dQs_up', 'Qs_dn_run');
        for i = 1:numel(dbg.layers)
            L = dbg.layers(i);
            if ~L.active, continue; end
            % representative unit friction: within-crit if present, else beyond
            if L.within_crit, fd = L.f_down_within; fu = L.f_up_within; sv = L.sv_within;
            else,             fd = L.f_down_beyond; fu = L.f_up_beyond; sv = L.sv_beyond; end
            fprintf('%3d %6.2f %6.2f %5s %5.1f %7.1f %8.1f %7.2f %8.1f %8.1f %9.1f %9.1f %9.1f\n', ...
                L.index, L.z1, L.z2, L.soil_type, L.phi, L.cu, sv, ...
                L.delta_deg, fd, fu, L.dQs_down, L.dQs_up, L.Qs_down_running);
            if L.within_crit && L.beyond_crit
                fprintf('%23s split: %.2f ft within z_crit (f_dn=%.1f), %.2f ft beyond (f_dn=%.1f, sv held at %.1f psf)\n', ...
                    '', L.L_within, L.f_down_within, L.L_beyond, L.f_down_beyond, L.sv_beyond);
            end
        end
        T = dbg.tip;
        fprintf('--- DEBUG: tip ---\n');
        if isfinite(T.Nq)
            fprintf('  tip layer %d: sand, phi = %.1f deg, Nq = %.1f (%s)\n', ...
                T.tip_layer_index, T.phi_tip, T.Nq, dbg.pile.pile_type);
        else
            fprintf('  tip layer %d: clay, cu = %.0f psf, Nc = %.2f (z/B = %.1f)\n', ...
                T.tip_layer_index, T.cu_tip, T.Nc, T.z_over_B);
        end
        fprintf('  sigma_v @ min(embed, z_crit) = %.1f psf;  qp = %.1f psf', ...
            T.sigma_tip, T.qp);
        if T.q_limited, fprintf('  (q_limit governed, raw %.1f psf)', T.qp_raw); end
        fprintf(';  Qtip = %.3f kips\n', k(T.Qtip));
    end
end
