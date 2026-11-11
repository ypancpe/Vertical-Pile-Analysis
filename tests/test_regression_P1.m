function test_regression_P1()
%TEST_REGRESSION_P1 P-1 case must reproduce the ALLPILE-validated numbers.
%
% Proves the generalization did not change the NAVFAC physics: the frozen
% P-1 fixture (10-in round timber displacement pile, 24 ft embedment, B-7
% sand profile, K_down=1.8/K_up=0.7/Kf=0.8/PR=20) must match ALLPILE to
% within 0.5%:
%   side(down) 42.7 k, tip 52.5 k, total down 95.2 k, total up 16.3 k.
% (This comparison table used to live in the navfac/ driver; it now lives
% here, where a regression check belongs.)

    here = fileparts(mfilename('fullpath'));
    addpath(here);                       % for input_P1_regression
    addpath(fileparts(here));            % package root

    inp = input_P1_regression();
    res = ng_run_case(inp);
    cap = res.cap;  st = res.settlement;
    k = @(x) x / 1000;

    % ---- ALLPILE P-1 reference values [kips] ----
    ref = struct( ...
        'side_down',  42.722, ...
        'tip',        52.467, ...
        'total_down', 95.189, ...
        'side_up',    16.614, ...
        'total_up',   16.278);
    got = struct( ...
        'side_down',  k(cap.Qside_down), ...
        'tip',        k(cap.Qtip), ...
        'total_down', k(cap.Qdown_ult), ...
        'side_up',    k(cap.Qside_up), ...
        'total_up',   k(cap.Qup_ult));

    fprintf('\nREGRESSION: P-1 vs ALLPILE\n');
    fprintf('%-12s %10s %10s %8s\n', 'item', 'package', 'ALLPILE', 'diff%');
    fn = fieldnames(ref);
    rel_tol = 0.005;                     % 0.5%
    for i = 1:numel(fn)
        r = ref.(fn{i});  g = got.(fn{i});
        d = 100 * (g - r) / r;
        fprintf('%-12s %10.3f %10.3f %8.2f\n', fn{i}, g, r, d);
        assert_true(abs(g - r) <= rel_tol * abs(r), ...
            sprintf('%s = %.3f k differs from ALLPILE %.3f k by more than %.1f%%', ...
            fn{i}, g, r, 100 * rel_tol));
    end

    % ---- the rounded targets from the task spec (42.7/52.5/95.2/16.3) ----
    % package vs ALLPILE agreement is ~0.1%, so allow 0.1 k on the rounded
    % targets (the package reproduces the same 42.76/52.48/95.24/16.30 the
    % validated navfac/ + python implementations produce)
    assert_close('side (spec)',       got.side_down,  42.7, 0.1);
    assert_close('tip (spec)',        got.tip,        52.5, 0.1);
    assert_close('total down (spec)', got.total_down, 95.2, 0.1);
    assert_close('total up (spec)',   got.total_up,   16.3, 0.1);

    % ---- Vesic settlement: pinned against this package's own validated
    %      output (drift guard). This fixture has a 16 ft stick-up
    %      (L = 40 ft) where ALLPILE's P-1 run has none (L = 24 ft), so there
    %      is no ALLPILE number for it here; the like-for-like ALLPILE check
    %      of X_max and the work-load settlement is test_allpile_benchmark. ----
    assert_close('Cp (Table 8-3 sand/driven)', st.Cp, 0.03, 1e-12);
    assert_close('Xs',     st.Xs,     0.351546, 5e-4);
    assert_close('Xpp',    st.Xpp,    0.235619, 5e-4);
    assert_close('Xps',    st.Xps,    0.011923, 5e-4);
    assert_close('Xtotal', st.Xtotal, 0.599088, 1e-3);
    assert_close('Xmax == Xtotal (X_max unchanged)', st.Xmax, st.Xtotal, 0);

    % ---- applied-load settlement, 'vesic_linear' components ----
    % (always computed; s_applied itself defaults to the 'allpile' method,
    % checked below.) SHAFT-FIRST split. Q = 30.0 k is below Qside
    % (42.76 k), so the shaft takes the whole load and the tip term is zero.
    Q = 30000;  Qult = cap.Qdown_ult;  ratio = Q / Qult;
    assert_true(st.has_applied, 'applied-load block must run when Q_applied is set');
    assert_close('Q_applied echoed',  st.Q_applied, Q, 0);
    assert_close('Q/Qult ratio',      st.ratio, ratio, 1e-9);
    assert_close('Qwp + Qws == Q',    st.Qwp + st.Qws, Q, 1e-6);
    assert_close('Qws == min(Q, Qside)', st.Qws, min(Q, cap.Qside_down), 1e-9);
    assert_close('Qwp == Q - Qws',    st.Qwp, Q - st.Qws, 1e-9);
    assert_close('Qwp == 0 (Q < Qside)', st.Qwp, 0, 1e-9);
    % s2,s3 are Xpp,Xps scaled by the MOBILIZED fractions (not by Q/Qult)
    assert_close('s2 == Xpp*(Qwp/Qtip) (exact)', st.s2, ...
        st.Xpp * (st.Qwp / cap.Qtip), 1e-9);
    assert_close('s3 == Xps*(Qws/Qside) (exact)', st.s3, ...
        st.Xps * (st.Qws / cap.Qside_down), 1e-9);
    assert_close('s2 == 0 while Q <= Qside', st.s2, 0, 1e-12);
    % drift-guard pins (this package's own validated output, shaft-first split)
    assert_close('s1 (shaft)',    st.s1, 0.073339, 5e-4);
    assert_close('s2 (point)',    st.s2, 0.0,      5e-4);
    assert_close('s3 (transfer)', st.s3, 0.008365, 5e-4);
    assert_close('s_vesic_linear', st.s_vesic_linear, 0.081703, 1e-3);
    assert_close('s_vesic_linear == s1+s2+s3', st.s_vesic_linear, st.s1 + st.s2 + st.s3, 1e-12);

    % ---- applied-load settlement, default 'allpile' method ----
    assert_true(strcmp(st.settle_method, 'allpile'), 'default settle_method must be ''allpile''');
    assert_close('s_applied == s_allpile', st.s_applied, st.s_allpile, 0);
    assert_true(st.s_allpile > 0 && st.s_allpile < st.Xmax, ...
        's_allpile must be positive and below the ultimate bound');
    assert_close('Kqx == Q/s', st.Kqx, Q / st.s_allpile, 1e-6);
    % drift-guard pin. NOTE this exceeds s_vesic_linear here (the 16 ft
    % stick-up carries the full 30 k), unlike the no-stick-up ALLPILE runs;
    % no ALLPILE benchmark covers a stick-up, so this is a pin, not a match.
    assert_close('s_allpile', st.s_allpile, 0.102765, 5e-4);

    % ---- spot-check internals ----
    assert_close('z_crit (20D)', cap.z_crit, 20 * 10 / 12, 1e-9);
    assert_true(strncmp(cap.tip_desc, 'Sand', 4), 'tip should be sand / Nq method');

    fprintf('test_regression_P1: PASS\n');
end

function assert_close(name, got, want, tol)
    assert_true(abs(got - want) <= tol, ...
        sprintf('%s: got %.6g, want %.6g (+/- %.3g)', name, got, want, tol));
end

function assert_true(cond, msg)
    if ~cond
        error('navfac_general:testFail', 'FAIL: %s', msg);
    end
end
