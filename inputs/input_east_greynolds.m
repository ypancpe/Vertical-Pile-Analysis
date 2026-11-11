function inp = input_east_greynolds()
%Input of East Greynolds Park Project 14in square prestressed concrete pile
    inp.case_name = 'East Greynolds - 14in square ps pile';

    % ---------------- PILE ----------------
    inp.pile.shape          = 'square';
    inp.pile.size_in        = 14;
    inp.pile.embedment_ft   = 18.0;
    inp.pile.L              = 18.0;
    inp.pile.E              = 4768000;          % [psi]
    inp.pile.SW             = 156.5;              % [pcf]
    inp.pile.pile_type      = 'displacement';   % driven
    inp.pile.water_table_ft = 0.0;              % X ft below grade - exercises the
                                                % above/below-WT unit-weight split
    inp.pile.gamma_w        = 62.4;

    % ---------------- ANALYSIS PARAMETERS ----------------
    inp.par.K_down = 1.30;     % driven displacement pile, NAVFAC range 1.0-1.5
    inp.par.K_up   = 0.80;     %   "        "        "  , NAVFAC range 0.6-1.0

    % Kf, PR, FS, Cp ... all left at the documented defaults

    % ---------------- APPLIED LOAD ----------------
    inp.Q_applied = 9500;        % applied axial COMPRESSION (down) load [lb]
                              % Split is SHAFT-FIRST, so the point term s2 is zero
                              % for any load at or below the printed Qside; raise
                              % this above Qside to exercise the tip term too.

    % ---------------- SOIL LAYERS ----------------
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    inp.layers = [ ...
        Lr( 0, 16, 105, 42.6,  29, NaN), ...    
        Lr(16, 24, 107, 44.6,  30, NaN), ...    
        Lr(24, 50, 110, 47.6,  31, NaN)];       
end
