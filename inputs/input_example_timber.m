function inp = input_example_timber()
%INPUT_EXAMPLE_TIMBER Worked example: round timber pile, layered sand + clay seam.
%
% Demonstrates: round shape, water table BELOW the surface (4 ft), a clay
% interbed (15-20 ft), ALLPILE-style K overrides, and
% default-everything-else. (Generic example - not a project case.)

    inp.case_name = 'Example - 10in round timber pile';

    % ---------------- PILE ----------------
    inp.pile.shape          = 'round';
    inp.pile.size_in        = 10;
    inp.pile.embedment_ft   = 24.0;
    inp.pile.L              = 40.0;
    inp.pile.E              = 1.5e6;            % timber [psi]
    inp.pile.SW             = 37.5;             % timber [pcf]
    inp.pile.pile_type      = 'displacement';   % driven
    inp.pile.water_table_ft = 4.0;              % 4 ft below grade - exercises the
                                                % above/below-WT unit-weight split
    inp.pile.gamma_w        = 62.4;

    % ---------------- ANALYSIS PARAMETERS ----------------
    inp.par.K_down = 1.80;     % driven displacement pile, NAVFAC range 1.0-1.5
    inp.par.K_up   = 0.70;     %   "        "        "  , NAVFAC range 0.6-1.0
    inp.par.Kf     = 0.80;
    % Kf, PR, FS, Cp ... all left at the documented defaults

    % ---------------- APPLIED LOAD ----------------
    inp.Q_applied = 30000;    % applied axial COMPRESSION (down) load [lb];
                              % uplift is negative. s_applied uses the default
                              % 'allpile' t-z/q-w method (s_vesic_linear is the
                              % shaft-first linear estimate). The clay interbed
                              % triggers the cohesive-curve warning, by design.

    % ---------------- SOIL LAYERS ----------------
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    inp.layers = [ ...
        Lr( 0,  3, 105, 60,  34, NaN), ...    % loose sand
        Lr( 3,  8, 110, 60,  35, NaN), ...    % medium sand
        Lr( 8, 15, 110, 64,  37, NaN), ...    % dense sand
        Lr(15, 20, 115, 55, NaN, 1100), ...   % CLAY interbed (cu in psf)
        Lr(20, 28, 120, 69,  38, NaN), ...    % dense sand (pile tip at 24 ft)
        Lr(28, 38, 125, 72,  40, NaN), ...    % very dense sand
        Lr(38, 50, 115, 65,  33, NaN)];       % medium sand
end
