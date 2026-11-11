function test_allpile_benchmark()
%TEST_ALLPILE_BENCHMARK navfac_general vs ALLPILE 7 on the Cristobal Pier test cases.
%
% Runs all 17 ALLPILE vertical runs in allpile_benchmark_cases (11 piles, 5
% distinct soil profiles; compression and uplift work loads) and checks
% every ALLPILE output the package reproduces:
%   capacity  : side (down/up), tip, ultimate (down/up), allowable (down/up)
%   weight    : buoyant pile weight W
%   Vesic     : Xs, Xpp, Xps, X_max (ALLPILE's Xtop) at ultimate
%   work load : settlement at ALLPILE's work load (compression and uplift)
%
% Tolerances follow ALLPILE's PRINT precision, not the package's results:
%   capacity 0.2 %   (observed <= 0.13 %: ALLPILE integrates on a 500-node
%                     grid and v3 exactly; the residual is below what the
%                     printed inputs can resolve)
%   W        0.006 k (printed to 2 decimals)
%   Vesic    0.0006 in (printed to 3 decimals)
%   s_work   0.5 % + 0.000005 in (printed to 5 decimals)

    here = fileparts(mfilename('fullpath'));
    addpath(here);  addpath(fileparts(here));

    C = allpile_benchmark_cases();
    k = @(x) x / 1000;
    fails = {};

    fprintf('\nBENCHMARK: navfac_general vs ALLPILE 7 (%d runs)\n', numel(C));
    fprintf('%-10s %8s %8s %8s %8s %8s %8s | %9s %9s %7s\n', 'run', ...
        'side_dn', 'tip', 'ult_dn', 'side_up', 'ult_up', 'all_up', ...
        's_v3', 's_ALLP', 'ds%');
    worst = struct('cap', 0, 's', 0);
    for i = 1:numel(C)
        r = ng_run_case(C(i).inp);
        c = r.cap;  st = r.settlement;  R = C(i).ref;
        id = C(i).id;

        % ---- capacity: relative ----
        got = [k(c.Qside_down), k(c.Qtip), k(c.Qdown_ult), k(c.Qdown_allow), ...
               k(c.Qside_up), k(c.Qup_ult), k(c.Qup_allow)];
        ref = [R.Qside_down, R.Qtip, R.Qdown_ult, R.Qdown_allow, ...
               R.Qside_up, R.Qup_ult, R.Qup_allow];
        names = {'Qside_down', 'Qtip', 'Qdown_ult', 'Qdown_allow', 'Qside_up', 'Qup_ult', 'Qup_allow'};
        pct = 100 * (got - ref) ./ abs(ref);
        worst.cap = max(worst.cap, max(abs(pct)));
        for j = 1:numel(names)
            if abs(pct(j)) > 0.2
                fails{end+1} = sprintf('%s %s: %.3f vs ALLPILE %.3f k (%.3f%%)', ...
                    id, names{j}, got(j), ref(j), pct(j)); %#ok<AGROW>
            end
        end

        % ---- weight ----
        if abs(k(c.W) - R.W) > 0.006
            fails{end+1} = sprintf('%s W: %.4f vs ALLPILE %.2f k', id, k(c.W), R.W); %#ok<AGROW>
        end

        % ---- Vesic at ultimate (compression runs) ----
        if ~isnan(R.Xs)
            vg = [st.Xs, st.Xpp, st.Xps, st.Xmax];  vr = [R.Xs, R.Xpp, R.Xps, R.Xtop];
            vn = {'Xs', 'Xpp', 'Xps', 'Xmax'};
            for j = 1:4
                if abs(vg(j) - vr(j)) > 0.0006
                    fails{end+1} = sprintf('%s %s: %.4f vs ALLPILE %.3f in', ...
                        id, vn{j}, vg(j), vr(j)); %#ok<AGROW>
                end
            end
        end

        % ---- work-load settlement ----
        s = st.s_applied;  sr = R.settle_work;
        ds = 100 * (s - sr) / abs(sr);
        worst.s = max(worst.s, abs(ds));
        if ~(abs(s - sr) <= 0.005 * abs(sr) + 0.000005)
            fails{end+1} = sprintf('%s s_work at %.2f k: %.6f vs ALLPILE %.5f in', ...
                id, R.Q_work, s, sr); %#ok<AGROW>
        end

        fprintf('%-10s %+7.3f%% %+7.3f%% %+7.3f%% %+7.3f%% %+7.3f%% %+7.3f%% | %9.6f %9.5f %+6.2f\n', ...
            id, pct(1), pct(2), pct(3), pct(5), pct(6), pct(7), s, sr, ds);
    end
    fprintf('max |capacity diff| = %.3f %%,  max |settlement diff| = %.2f %%\n', worst.cap, worst.s);

    if ~isempty(fails)
        error('navfac_general:testFail', 'FAIL (%d):\n  %s', numel(fails), strjoin(fails, '\n  '));
    end
    fprintf('test_allpile_benchmark: PASS\n');
end
