function test_validation()
%TEST_VALIDATION Input validation, warnings, and generalization behaviors.

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    addpath(fileparts(here));
    quiet = struct('opts', struct('verbose', false, 'print_layers', false, ...
                                  'write_csv', false));

    % ================= validation errors =================
    % layer gap
    inp = base_case();
    inp.layers(2).depth_top = 12;        % gap 10..12
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:layerGap');

    % layer overlap
    inp = base_case();
    inp.layers(2).depth_top = 8;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:layerOverlap');

    % first layer not at surface
    inp = base_case();
    inp.layers(1).depth_top = 1.0;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:layersStart');

    % both phi and cu set
    inp = base_case();
    inp.layers(1).cu = 500;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:bothPhiCu');

    % neither phi nor cu
    inp = base_case();
    inp.layers(1).phi = NaN;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:neitherPhiCu');

    % embedment below the layer stack
    inp = base_case();
    inp.pile.embedment_ft = 99;
    inp.pile.L = 120;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:tipNotCovered');

    % bad shape
    inp = base_case();
    inp.pile.shape = 'hexagonal';
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:badShape');

    % bad pile_type
    inp = base_case();
    inp.pile.pile_type = 'driven';
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:badPileType');

    % L shorter than embedment
    inp = base_case();
    inp.pile.L = 10;
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:badLength');

    % missing required field
    inp = base_case();
    inp.pile = rmfield(inp.pile, 'E');
    expect_error(@() ng_run_case(inp, quiet), 'navfac_general:missingField');

    % ================= warnings =================
    % phi outside the Nq table range -> warn + clamp, not extrapolate/error
    inp = base_case();
    inp.layers(2).phi = 45;              % tip layer, above 40 deg
    res = run_warn(inp, quiet, 'navfac_general:NqOutOfRange');
    Nq40 = ng_nq_table(40, 'displacement');
    assert_close('Nq clamped to phi=40', res.dbg.tip.Nq, Nq40, 1e-9);

    % unknown par field -> warn (typo guard)
    inp = base_case();
    inp.par.K_dwn = 1.5;                 % typo of K_down
    run_warn(inp, quiet, 'navfac_general:unknownField');

    % ================= generalization sanity =================
    % square pile geometry: A = b^2, P = 4b
    inp = base_case();
    inp.pile.shape = 'square';
    res = ng_run_case(inp, quiet);
    b = inp.pile.size_in / 12;
    assert_close('square A', res.cap.A, b^2, 1e-12);
    assert_close('square P', res.cap.P, 4 * b, 1e-12);

    % K_up < K_down  =>  uplift side < compression side (sand)
    res = ng_run_case(base_case(), quiet);
    assert_true(res.cap.Qside_up < res.cap.Qside_down, ...
        'with K_up < K_down, Qside_up must be < Qside_down in sand');
    assert_close('Qs up/down ratio = K_up/K_down (all-sand case)', ...
        res.cap.Qside_up / res.cap.Qside_down, ...
        res.inp.par.K_up / res.inp.par.K_down, 1e-9);

    % deep clay tip: Nc = 9, adhesion identical down and up
    inp = base_case();
    inp.layers(2).phi = NaN;  inp.layers(2).cu = 1200;
    res = ng_run_case(inp, quiet);
    assert_close('deep clay Nc', res.dbg.tip.Nc, 9.0, 1e-9);
    assert_close('clay tip qp = Nc*cu', res.cap.qp, 9.0 * 1200, 1e-9);
    Lc = res.dbg.layers(2);
    assert_close('clay f same down/up', Lc.f_down_within, Lc.f_up_within, 1e-12);
    assert_close('clay Ca = Kc*Ka*cu', Lc.Ca_psf, ...
        res.inp.par.Kc * res.inp.par.Ka * 1200, 1e-9);

    % critical depth cap: sigma_v beyond z_crit is held at sigma_v(z_crit)
    res = ng_run_case(base_case(), quiet);
    z_crit = res.cap.z_crit;
    sv_crit = ng_vertical_stress(z_crit, res.inp.layers, res.inp.pile.water_table_ft);
    for i = 1:numel(res.dbg.layers)
        L = res.dbg.layers(i);
        if L.active && L.beyond_crit
            assert_close(sprintf('layer %d sv_beyond == sv(z_crit)', i), ...
                L.sv_beyond, sv_crit, 1e-9);
        end
    end

    % tip sigma also capped at z_crit
    assert_close('sigma_tip = sv(z_crit) when embed > z_crit', ...
        res.dbg.tip.sigma_tip, sv_crit, 1e-9);

    % water table below mudline: less buoyancy => heavier pile (larger W)
    dry = base_case();  dry.pile.water_table_ft = 10;
    res_dry = ng_run_case(dry, quiet);
    res_wet = ng_run_case(base_case(), quiet);
    assert_true(res_dry.cap.W > res_wet.cap.W, ...
        'lowering the water table must increase the effective pile weight');
    % and stresses increase => more side friction
    assert_true(res_dry.cap.Qside_down > res_wet.cap.Qside_down, ...
        'lowering the water table must increase side friction');

    % f_limit cap engages and is flagged
    capd = base_case();  capd.par.f_limit = 100;
    res_cap = ng_run_case(capd, quiet);
    assert_true(any([res_cap.dbg.layers.f_limited]), 'f_limit must flag at least one layer');
    assert_true(res_cap.cap.Qside_down < res_wet.cap.Qside_down, ...
        'f_limit must reduce side resistance');

    % q_limit cap engages
    capq = base_case();  capq.par.q_limit = 5000;
    res_q = ng_run_case(capq, quiet);
    assert_true(res_q.dbg.tip.q_limited, 'q_limit must be flagged');
    assert_close('qp at q_limit', res_q.cap.qp, 5000, 1e-9);

    % nondisplacement pile: lower Nq and bored Cp
    nd = base_case();  nd.pile.pile_type = 'nondisplacement';
    res_nd = ng_run_case(nd, quiet);
    assert_true(res_nd.cap.Qtip < res_wet.cap.Qtip, ...
        'nondisplacement Nq must give a smaller tip than displacement');
    assert_close('bored sand Cp', res_nd.settlement.Cp, 0.135, 1e-12);

    % batch summary row is CSV-serializable
    row = ng_summary_row(res_wet.inp, res_wet.cap, res_wet.settlement);
    tmp = tempname();
    ng_write_csv(row, tmp);
    delete(tmp);

    % non-scalar fields must be rejected, not silently flattened
    expect_error(@() ng_write_csv(struct('a', 1, 'flags', [true false]), tempname()), ...
        'navfac_general:badCsvField');

    % typo'd OPTIONAL pile field must warn (silent-default trap)
    inp = base_case();
    inp.pile.piletype = 'nondisplacement';   % typo of pile_type
    run_warn(inp, quiet, 'navfac_general:unknownField');

    % ng_vertical_stress: vectorized two-output call, row AND column z
    lyrs = res_wet.inp.layers;
    [se_r, sa_r] = ng_vertical_stress([5 15 25], lyrs, 0);
    [se_c, sa_c] = ng_vertical_stress([5; 15; 25], lyrs, 0);
    assert_true(isequal(size(se_r), [1 3]) && isequal(size(sa_r), [1 3]), ...
        'row z must give row outputs');
    assert_close('row/col sigma_eff agree', max(abs(se_r(:) - se_c(:))), 0, 1e-12);
    assert_close('row/col sigma_avg agree', max(abs(sa_r(:) - sa_c(:))), 0, 1e-12);
    assert_close('sigma_eff(15)', se_r(2), 10*60 + 5*64, 1e-9);

    % water-table kink: result must not depend on splitting layers at the WT
    one = base_case();  one.pile.water_table_ft = 5;
    two = one;
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    two.layers = [Lr(0, 5, 110, 60, 32, NaN), Lr(5, 10, 110, 60, 32, NaN), ...
                  two.layers(2)];
    r_one = ng_run_case(one, quiet);
    r_two = ng_run_case(two, quiet);
    assert_close('Qside invariant to splitting at WT', ...
        r_one.cap.Qside_down, r_two.cap.Qside_down, 1e-6);

    % per-layer delta_deg override (steel-pile constant delta)
    stl = base_case();
    stl.layers(1).delta_deg = 20;  stl.layers(2).delta_deg = 20;
    r_stl = ng_run_case(stl, quiet);
    assert_close('delta_deg override logged', r_stl.dbg.layers(1).delta_deg, 20, 1e-12);
    f_expect = r_stl.inp.par.K_down * r_stl.dbg.layers(1).sv_within * tan(deg2rad(20));
    assert_close('delta_deg override applied to f', ...
        r_stl.dbg.layers(1).f_down_within, f_expect, 1e-9);
    % delta_deg on a clay layer warns and is ignored
    dcl = base_case();
    dcl.layers(1).phi = NaN;  dcl.layers(1).cu = 900;  dcl.layers(1).delta_deg = 20;
    dcl.layers(2).delta_deg = NaN;
    run_warn(dcl, quiet, 'navfac_general:deltaOnClay');

    % ================= applied-load settlement (additive) =================
    % absent Q_applied -> only the ultimate bound; applied block skipped, no error
    res_base = ng_run_case(base_case(), quiet);
    assert_true(~res_base.settlement.has_applied, ...
        'no Q_applied -> applied-load block must be skipped');
    assert_true(isnan(res_base.settlement.s_applied), 's_applied must be NaN when skipped');
    assert_true(isfinite(res_base.settlement.Xmax) && res_base.settlement.Xmax > 0, ...
        'X_max must still be reported when Q_applied is absent');
    assert_close('Xmax == Xtotal', res_base.settlement.Xmax, res_base.settlement.Xtotal, 0);

    % Q_applied present -> SHAFT-FIRST split; s2/s3 scale Xpp/Xps by the
    % mobilized tip/shaft fractions
    ap = base_case();  ap.Q_applied = 20000;
    rA = ng_run_case(ap, quiet);  sA = rA.settlement;  cA = rA.cap;
    assert_true(sA.has_applied, 'Q_applied set -> applied-load block must run');
    assert_close('Qwp + Qws == Q_applied', sA.Qwp + sA.Qws, 20000, 1e-6);
    assert_close('Qws == min(Q, Qside)', sA.Qws, min(20000, cA.Qside_down), 1e-9);
    assert_close('Qwp == Q - Qws', sA.Qwp, 20000 - sA.Qws, 1e-9);
    assert_close('s2 == Xpp*(Qwp/Qtip)', sA.s2, sA.Xpp * (sA.Qwp / cA.Qtip), 1e-9);
    assert_close('s3 == Xps*(Qws/Qside)', sA.s3, sA.Xps * (sA.Qws / cA.Qside_down), 1e-9);
    assert_true(sA.s_applied < sA.Xmax, 's_applied must be below the ultimate bound (Q < Qult)');

    % shaft-first, below Qside: the tip carries NOTHING and s2 is exactly zero
    cap_b = res_base.cap;
    lo = base_case();  lo.Q_applied = 0.5 * cap_b.Qside_down;
    sLo = ng_run_case(lo, quiet).settlement;
    assert_close('Qwp == 0 for Q < Qside', sLo.Qwp, 0, 1e-9);
    assert_close('s2 == 0 for Q < Qside',  sLo.s2,  0, 1e-12);

    % shaft-first, above Qside: shaft saturates and the excess goes to the tip
    hi = base_case();  hi.Q_applied = cap_b.Qside_down + 5000;
    sHi = ng_run_case(hi, quiet).settlement;
    assert_close('Qws saturates at Qside', sHi.Qws, cap_b.Qside_down, 1e-6);
    assert_close('Qwp == excess above Qside', sHi.Qwp, 5000, 1e-6);
    assert_true(sHi.s2 > 0, 's2 must be positive once Q exceeds Qside');

    % xi override flows into the shaft-shortening term s1
    x1 = base_case();  x1.Q_applied = 20000;  x1.par.xi = 0.5;
    x2 = base_case();  x2.Q_applied = 20000;  x2.par.xi = 0.67;
    s1lo = ng_run_case(x1, quiet).settlement;
    s1hi = ng_run_case(x2, quiet).settlement;
    assert_close('xi echoed', s1lo.xi, 0.5, 1e-12);
    assert_true(s1hi.s1 > s1lo.s1, 'larger xi must increase the shaft-shortening term s1');

    % Q_applied = 0 is VALID (and distinct from absent): the block runs and
    % every applied-load term comes out zero
    z0 = base_case();  z0.Q_applied = 0;
    sZ = ng_run_case(z0, quiet).settlement;
    assert_true(sZ.has_applied, 'Q_applied = 0 must still run the applied-load block');
    assert_close('Qws == 0 at zero load', sZ.Qws, 0, 0);
    assert_close('Qwp == 0 at zero load', sZ.Qwp, 0, 0);
    assert_close('s1 == 0 at zero load',  sZ.s1,  0, 0);
    assert_close('s2 == 0 at zero load',  sZ.s2,  0, 0);
    assert_close('s3 == 0 at zero load',  sZ.s3,  0, 0);
    assert_close('s_applied == 0 at zero load', sZ.s_applied, 0, 0);
    assert_true(isfinite(sZ.Xmax) && sZ.Xmax > 0, ...
        'X_max must be unaffected by a zero applied load');

    % zero load under the default 'allpile' method: exactly zero too (the
    % compression load-settlement curve starts at the origin)
    assert_close('s_allpile == 0 at zero load', sZ.s_allpile, 0, 0);

    % invalid Q_applied (non-finite) -> error. Negative is VALID (uplift).
    bad = base_case();  bad.Q_applied = Inf;
    expect_error(@() ng_run_case(bad, quiet), 'navfac_general:badQapplied');

    % ================= settlement method + uplift =================
    % 'allpile' is the default; s_applied is s_allpile, and both are reported
    assert_true(strcmp(sA.settle_method, 'allpile'), 'default settle_method must be ''allpile''');
    assert_close('s_applied == s_allpile (default)', sA.s_applied, sA.s_allpile, 0);
    assert_close('s_vesic_linear == s1+s2+s3', sA.s_vesic_linear, sA.s1 + sA.s2 + sA.s3, 1e-12);
    assert_true(sA.s_allpile > 0 && sA.s_allpile < sA.Xmax, ...
        's_allpile must be positive and below the ultimate bound');
    % the load-settlement table is monotonic in displacement and ends at X_max
    assert_true(all(diff(sA.lt.down.Xtip) > 0), 'compression table: Xtip must increase');
    assert_close('compression table ends at Xtip = X_max', sA.lt.down.Xtip(end), sA.Xmax, 1e-12);

    % 'vesic_linear' selects the shaft-first estimate
    vl = base_case();  vl.Q_applied = 20000;  vl.par.settle_method = 'vesic_linear';
    sVL = ng_run_case(vl, quiet).settlement;
    assert_close('vesic_linear: s_applied == s_vesic_linear', sVL.s_applied, sVL.s_vesic_linear, 0);
    assert_close('method choice does not change s_allpile', sVL.s_allpile, sA.s_allpile, 1e-12);

    bm = base_case();  bm.par.settle_method = 'tz';
    expect_error(@() ng_run_case(bm, quiet), 'navfac_general:badSettleMethod');

    % uplift (Q < 0): upward (negative) movement; vesic_linear is undefined
    upl = base_case();  upl.Q_applied = -5000;
    sU = ng_run_case(upl, quiet).settlement;
    assert_true(sU.has_applied && strcmp(sU.lt_mode, 'up'), 'Q < 0 must run the uplift branch');
    assert_true(sU.s_applied < 0, 'uplift movement must be negative (upward)');
    assert_true(isnan(sU.s_vesic_linear), 's_vesic_linear must be NaN for uplift');
    assert_close('uplift table ends at -X_up_max', sU.lt.up.Xtop(end), -sU.X_up_max, 1e-12);
    upv = upl;  upv.par.settle_method = 'vesic_linear';
    run_warn(upv, quiet, 'navfac_general:vesicLinearUplift');

    % ================= allowable uplift: W carries its own FS =================
    r_fs = ng_run_case(base_case(), quiet);  cF = r_fs.cap;
    assert_close('Qup_allow == Qside_up/FS_uplift + W/FS_weight', cF.Qup_allow, ...
        cF.Qside_up / 3 + cF.W / 1, 1e-9);
    fw = base_case();  fw.par.FS_weight = 2;
    cW = ng_run_case(fw, quiet).cap;
    assert_close('FS_weight override', cW.Qup_allow, cW.Qside_up / 3 + cW.W / 2, 1e-9);
    bw = base_case();  bw.par.FS_weight = 0.5;
    expect_error(@() ng_run_case(bw, quiet), 'navfac_general:badFS');

    % Q_applied >= ultimate capacity -> warn; vesic_linear still reports
    over = base_case();  over.Q_applied = 1e9;  over.par.settle_method = 'vesic_linear';
    r_over = run_warn(over, quiet, 'navfac_general:loadExceedsCapacity');
    assert_true(isfinite(r_over.settlement.s_applied), ...
        'over-capacity case must still report the vesic_linear s_applied');
    % ... while the 'allpile' curve has no point that high: NaN + its own warning
    over2 = base_case();  over2.Q_applied = 1e9;
    r_over2 = run_warn(over2, quiet, 'navfac_general:beyondLoadCurve');
    assert_true(isnan(r_over2.settlement.s_applied), ...
        'a load beyond the allpile load-settlement curve must give NaN (ALLPILE: 99999)');

    fprintf('test_validation: PASS\n');
end

% ------------------------------------------------------------- fixtures
function inp = base_case()
    % minimal valid all-sand case: 12-in round driven pile, 25 ft embedment
    % (z_crit = 20*1 ft = 20 ft < embedment, so the beyond-critical branch
    % and the tip cap are both exercised)
    inp.case_name = 'validation base case';
    inp.pile = struct('shape', 'round', 'size_in', 12, 'embedment_ft', 25, ...
        'L', 35, 'E', 1.5e6, 'SW', 45, 'water_table_ft', 0, ...
        'gamma_w', 62.4, 'pile_type', 'displacement');
    inp.par = struct('K_down', 1.2, 'K_up', 0.7);
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    inp.layers = [Lr(0, 10, 110, 60, 32, NaN), Lr(10, 40, 115, 64, 36, NaN)];
end

% ------------------------------------------------------------- helpers
function expect_error(fn, id)
    try
        fn();
    catch err
        if strcmp(err.identifier, id), return; end
        error('navfac_general:testFail', ...
            'FAIL: expected error "%s" but got "%s" (%s)', id, err.identifier, err.message);
    end
    error('navfac_general:testFail', 'FAIL: expected error "%s" but none was raised', id);
end

function res = run_warn(inp, quiet, id)
    lastwarn('', '');
    res = ng_run_case(inp, quiet);
    [~, warn_id] = lastwarn();
    if ~strcmp(warn_id, id)
        error('navfac_general:testFail', ...
            'FAIL: expected warning "%s" but got "%s"', id, warn_id);
    end
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
