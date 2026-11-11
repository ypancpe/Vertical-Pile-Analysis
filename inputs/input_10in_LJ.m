function inp = input_10in_LJ()
%INPUT_TEMPLATE Template input file - copy, rename (input_<case>.m), and edit.
%
% One file = one case. Run it with:
%   >> results = ng_run_case('input_<case>');         % or via pile_calc.m
% Run all cases at once with:
%   >> pile_calc_batch
%
% Only pile geometry/material and the soil layers are REQUIRED. Every
% analysis parameter has a documented default (see ng_defaults.m); set a
% field below only to override it. Units: ft, in, deg, psf, pcf, psi, lb.

    % ---------------- CASE INFO ----------------
    inp.case_name = 'Liza Jackson 10in';

    % ---------------- PILE (required) ----------------
    inp.pile.shape        = 'round';   % 'round' or 'square'
    inp.pile.size_in      = 10;         % diameter or width [in]
    inp.pile.embedment_ft = 15;       % embedded depth below surface/mudline [ft]
    inp.pile.L            = 28.5;       % total pile length (embedment + stick-up) [ft]
    inp.pile.E            = 1500000;    % pile modulus of elasticity [psi]
    inp.pile.SW           = 37.5;        % pile material unit weight [pcf]

    % ---------------- APPLIED LOAD (optional) ----------------
    % Applied axial COMPRESSION (downward) load [lb] for the service-
    % settlement check. Leave NaN (or omit) to report only the ultimate
    % upper-bound settlement X_max; set a value to also get s_applied.
    % Zero is allowed, and is not the same as NaN: it runs the applied-load
    % block and reports s_applied = 0.
    % s_applied uses par.settle_method (default 'allpile', ALLPILE's t-z/q-w
    % relation); the shaft-first linear estimate is still s_vesic_linear.
    inp.Q_applied = 6927;        % e.g. 30000 for a 30-kip service load [lb]

    % ---------------- PILE (optional - defaults shown) ----------------
    inp.pile.pile_type      = 'displacement';  % 'displacement' (driven) | 'nondisplacement' (bored)
    inp.pile.water_table_ft = 0.0;             % water table depth BELOW surface [ft]; 0 = at/above
    inp.pile.gamma_w        = 64.0;            % water unit weight for buoyancy [pcf] (64.0 seawater)
    % inp.pile.A = 363;                        % geometry overrides [in^2] / [in]
    % inp.pile.P = 56;                         %   (e.g. H-pile or hollow section)

    % ---------------- ANALYSIS PARAMETERS (optional - see ng_defaults.m) ----------------
    inp.par.K_down    = 1.8;     % earth-pressure coeff., compression side friction
    inp.par.K_up      = 0.7;     % earth-pressure coeff., uplift side friction
    inp.par.Kf        = 0.80;    % pinned to the ALLPILE/P-1 calibration value, so this
                                 % case is unaffected by the package default (0.75 =
                                 % NAVFAC 3/4*phi for concrete/timber). Change to 0.75
                                 % to adopt the generic NAVFAC value here.
    % inp.par.Kc        = 1.0;     % clay adhesion Ca = Kc*Ka*cu
    % inp.par.Ka        = 1.0;
    % inp.par.PR        = 20.0;    % critical depth z_crit = PR*D
    % inp.par.FS_tip    = 3.0;
    % inp.par.FS_side   = 3.0;
    % inp.par.FS_uplift = 3.0;
    % inp.par.f_limit   = NaN;     % unit side friction cap [psf] (NaN = off)
    % inp.par.q_limit   = NaN;     % unit tip bearing cap [psf] (NaN = off)
    % inp.par.Cp        = NaN;     % Vesic Cp (NaN = auto from Table 8-3)
    % inp.par.xi        = 0.6;     % Vesic shaft-shortening coeff (range 0.5-0.67)
    % inp.par.Q_work    = NaN;     % working load, reference only [lb]

    % ---------------- OUTPUT OPTIONS (optional) ----------------
    % inp.opts.verbose      = true;   % console summary
    % inp.opts.print_layers = true;   % console per-layer debug table
    % inp.opts.write_csv    = true;   % per-layer + summary CSVs in /outputs

    % ---------------- SOIL LAYERS (required) ----------------
    % Contiguous from the surface (depth_top of layer 1 must be 0) and deep
    % enough to cover the pile tip. Each layer is sand (phi>0 [deg], cu=NaN)
    % XOR clay (cu>0 [psf], phi=NaN). gamma_above = total unit weight used
    % above the water table; gamma_below = buoyant unit weight used below.
    % Optional: add a 'delta_deg' field to fix the interface friction angle
    % of a sand layer (overrides Kf*phi - e.g. NAVFAC's delta = 20 deg for
    % steel piles). If used, give EVERY layer the field (NaN = no override),
    % since MATLAB struct arrays need uniform fields.
    Lr = @(dt, db, ga, gb, phi, cu) struct('depth_top', dt, 'depth_bot', db, ...
        'gamma_above', ga, 'gamma_below', gb, 'phi', phi, 'cu', cu);
    inp.layers = [ ...
        Lr( 0.0,  5.0, 105, 45,  28, NaN), ...   % sand
        Lr( 5.0, 10.0, 105, 45,  31, NaN), ...   % sand
        Lr(10.0, 60.0, 105, 45,  34, NaN)];      % sand
end
