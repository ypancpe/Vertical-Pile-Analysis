function inp = input_P1_regression()
%INPUT_P1_REGRESSION Frozen P-1 regression fixture (ALLPILE-validated). DO NOT EDIT.
%
% 10-in round timber displacement pile, 24 ft embedment, boring B-7 sand
% profile, with the exact ALLPILE Setup/Advanced parameters used for the
% validated run (K_down=1.8, K_up=0.7, Kf=0.8, PR=20, FS=3, Cp=0.03).
% These project-specific values live HERE - in the test fixture - not in
% the package defaults or calc functions. Expected results (ALLPILE):
%   side(down) 42.722 k, tip 52.467 k, total down 95.189 k,
%   side(up) 16.614 k, total up 16.278 k.
% test_regression_P1.m asserts against these; if you change ANY of the
% pile/par/layer values here the regression test is meaningless. (The
% Q_applied below is the ONLY additive field - it drives the new
% applied-load settlement and does NOT affect the frozen ULTIMATE results.)

    inp.case_name = 'P-1 regression (NAVFAC DM-7.02 / ALLPILE basis)';

    % ---------------- APPLIED LOAD (additive; no effect on ultimate) ----------------
    inp.Q_applied = 30000.0;     % [lb] exercises the applied-load settlement

    % ---------------- PILE ----------------
    inp.pile.shape          = 'round';
    inp.pile.size_in        = 10.0;
    inp.pile.embedment_ft   = 24.0;
    inp.pile.L              = 40.0;
    inp.pile.E              = 1.5e6;
    inp.pile.SW             = 37.5;
    inp.pile.gamma_w        = 62.4;
    inp.pile.pile_type      = 'displacement';
    inp.pile.water_table_ft = 0.0;

    % ---------------- ANALYSIS PARAMETERS (ALLPILE Setup/Advanced) ----------------
    inp.par.K_down    = 1.8;
    inp.par.K_up      = 0.7;
    inp.par.Kf        = 0.8;
    inp.par.Kc        = 1.0;
    inp.par.Ka        = 1.0;
    inp.par.PR        = 20.0;
    inp.par.FS_tip    = 3.0;
    inp.par.FS_side   = 3.0;
    inp.par.FS_uplift = 3.0;
    inp.par.f_limit   = NaN;
    inp.par.q_limit   = NaN;
    inp.par.Cp        = 0.03;        % Table 8-3, sand / driven
    inp.par.Q_work    = 3380.0;      % reference only

    % ---------------- SOIL LAYERS (B-7, depths below mudline) ----------------
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    inp.layers = [ ...
        Lr( 0,  3, 105, 60, 34, NaN), ...
        Lr( 3,  8, 110, 60, 35, NaN), ...
        Lr( 8, 23, 110, 64, 37, NaN), ...
        Lr(23, 28, 120, 69, 38, NaN), ...
        Lr(28, 38, 125, 72, 40, NaN), ...
        Lr(38, 41, 115, 65, 33, NaN)];

    % keep the regression run quiet; the test prints its own table
    inp.opts.verbose      = false;
    inp.opts.print_layers = false;
    inp.opts.write_csv    = false;
end
