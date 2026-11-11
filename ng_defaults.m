function def = ng_defaults()
%NG_DEFAULTS Documented default analysis parameters and options (NAVFAC DM-7.02).
%
%   def = ng_defaults() returns a struct with three fields:
%     def.par  - analysis parameters (merged under any user-supplied inp.par)
%     def.pile - optional pile fields and their defaults
%     def.opts - output/logging options
%
%   Every value here can be overridden per case in the input file. NOTHING in
%   the calculation functions is hardcoded; they read everything from these
%   structs.
%
%   ---------------------------------------------------------------------
%   ANALYSIS PARAMETERS (def.par)                       [units]   source
%   ---------------------------------------------------------------------
%   K_down   Lateral earth-pressure coefficient, side friction in
%            COMPRESSION (K_HC). NAVFAC DM-7.02 ranges:
%              driven H-pile             0.5 - 1.0
%              driven displacement pile  1.0 - 1.5
%              driven tapered pile       1.5 - 2.0
%              driven jetted pile        0.4 - 0.9
%              bored pile (< 24 in)      0.7
%            Default 1.0 (driven displacement pile, lower bound). [-]
%
%   K_up     Lateral earth-pressure coefficient, side friction in
%            UPLIFT (K_HT). NAVFAC DM-7.02 ranges:
%              driven H-pile             0.3 - 0.5
%              driven displacement pile  0.6 - 1.0
%              driven tapered pile       1.0 - 1.3
%              driven jetted pile        0.3 - 0.6
%              bored pile (< 24 in)      0.4
%            Default 0.7 (driven displacement pile, lower-middle of the
%            range). [-]
%
%   Kf       Interface-friction factor: delta = Kf * phi.
%            NAVFAC DM-7.02: concrete/timber piles delta = 3/4*phi
%            (Kf = 0.75, the default); steel piles use a CONSTANT
%            delta = 20 deg - Kf = 20/phi only reproduces that when every
%            sand layer shares one phi, so for steel (or any fixed delta)
%            set the optional per-layer field layers(i).delta_deg instead,
%            which overrides Kf*phi for that layer. [-]
%
%   Kc, Ka   Clay adhesion multipliers: Ca = Kc * Ka * cu. Defaults 1.0
%            (full adhesion, Ca = cu). Reduce to match an adhesion table
%            (e.g. NAVFAC DM-7.02 Table 2 / ALLPILE Ca curves). [-]
%
%   PR       Critical-depth penetration ratio: z_crit = PR * D. Effective
%            vertical stress used for side friction AND tip bearing is
%            capped at its value at z_crit. Customary range 10 - 20
%            depending on relative density; 20 is the ALLPILE/NAVFAC
%            deep-pile default. [-]
%
%   FS_tip, FS_side, FS_uplift
%            Factors of safety. Allowable(down) = Qtip/FS_tip +
%            Qside/FS_side. Default 3.0 each (NAVFAC DM-7.02 static
%            analysis without a load test). [-]
%
%   FS_weight  Factor of safety on the (buoyant) pile weight W in the
%            allowable UPLIFT capacity, as ALLPILE (manual 8.1.1.7):
%              Allowable(up) = Qside_up/FS_uplift + W/FS_weight
%            Default 1.0 (ALLPILE's default). [-]
%
%   f_limit  Absolute cap on unit side friction [psf]. NaN = no cap.
%   q_limit  Absolute cap on unit tip bearing  [psf]. NaN = no cap.
%
%   Cp       Vesic (1977) empirical tip coefficient for settlement
%            (ALLPILE Table 8-3). NaN (default) = pick automatically from
%            ng_cp_table(tip soil type, pile_type):
%              sand: driven 0.02-0.04 (mid 0.03), bored 0.09-0.18 (mid 0.135)
%              clay: driven 0.02-0.03 (mid 0.025), bored 0.03-0.06 (mid 0.045)
%            Set a number to override. [-]
%
%   settle_dz  Nominal slice thickness for the axial-shortening
%              integration in ng_settlement_vesic. [ft]
%
%   settle_method  How s_applied (settlement at inp.Q_applied) is computed:
%            'allpile' (default) - ALLPILE 7's load-settlement relation from
%                the Reese & O'Neill t-z/q-w curves scaled by the Vesic
%                settlement (Advanced page "Option 2"); compression and
%                uplift. Matches ALLPILE's work-load settlement on the
%                benchmark (tests/test_allpile_benchmark.m).
%            'vesic_linear' - linear Vesic estimate with a shaft-first load
%                split; compression only. Runs 11-17% above ALLPILE.
%            Both are always computed (st.s_allpile, st.s_vesic_linear);
%            this only selects which one is s_applied.
%
%   xi       Vesic shaft-shortening coefficient in the 'vesic_linear'
%            settlement s1 = (Qwp + xi*Qws)*L/(Ap*Ep). It reflects the
%            distribution of side resistance along the shaft; range
%            0.5 (uniform) to 0.67 (triangular), default 0.6. [-]
%            ('allpile' uses ALLPILE's own fixed 0.5, not this value.)
%
%   Q_work   Optional working load, echoed for reference only. NOT the load
%            used for the applied-load settlement - that is inp.Q_applied
%            (see TOP-LEVEL INPUTS below). [lb]
%
%   ---------------------------------------------------------------------
%   TOP-LEVEL INPUTS (alongside inp.pile / inp.par / inp.layers)
%   ---------------------------------------------------------------------
%   Q_applied  Applied axial load for the service-settlement check [lb]:
%              COMPRESSION (downward) > 0, UPLIFT < 0 - ALLPILE's sign
%              convention. Defaulted to NaN in ng_apply_defaults: NaN or
%              absent => the applied-load settlement block is skipped and
%              only the ultimate (upper-bound) Vesic settlement X_max is
%              reported. Zero is allowed and is NOT the same as absent -
%              the block runs and reports s_applied = 0. Uplift movement
%              comes out negative (upward) and needs settle_method
%              'allpile'. A load >= the ultimate capacity in its direction
%              warns.
%
%   ---------------------------------------------------------------------
%   PILE DEFAULTS (def.pile) - merged under inp.pile
%   ---------------------------------------------------------------------
%   pile_type      'displacement' (driven) | 'nondisplacement' (bored).
%                  Selects the Nq column of Table 8-1 and the Cp column of
%                  Table 8-3. Default 'displacement'.
%   water_table_ft Depth of water table BELOW the ground surface/mudline
%                  [ft]. 0 = water at/above surface (fully buoyant).
%   gamma_w        Unit weight of water for pile buoyancy [pcf].
%                  Default 62.4 (fresh); use 64.0 for seawater.
%
%   Required pile fields (no defaults): shape ('round'|'square'), size_in
%   [in], embedment_ft [ft], L [ft, total length], E [psi], SW [pcf].
%   Optional: A [in^2], P [in] geometry overrides (see ng_pile_geometry).
%
%   ---------------------------------------------------------------------
%   OPTIONS (def.opts)
%   ---------------------------------------------------------------------
%   verbose       Print the results summary to the console.        (true)
%   print_layers  Print the per-layer debug table to the console.  (true)
%   write_csv     Write per-layer + summary CSVs to outputs/.      (true)
%   output_dir    Override output folder ('' = <package>/outputs). ('')

    def.par = struct( ...
        'K_down',    1.0, ...
        'K_up',      0.7, ...
        'Kf',        0.8, ...
        'Kc',        1.0, ...
        'Ka',        1.0, ...
        'PR',        20.0, ...
        'FS_tip',    3.0, ...
        'FS_side',   3.0, ...
        'FS_uplift', 3.0, ...
        'FS_weight', 1.0, ...
        'f_limit',   NaN, ...
        'q_limit',   NaN, ...
        'Cp',        NaN, ...
        'settle_dz', 0.05, ...
        'settle_method', 'allpile', ...
        'xi',        0.6, ...
        'Q_work',    NaN);

    def.pile = struct( ...
        'pile_type',      'displacement', ...
        'water_table_ft', 0.0, ...
        'gamma_w',        62.4);

    def.opts = struct( ...
        'verbose',      true, ...
        'print_layers', true, ...
        'write_csv',    true, ...
        'output_dir',   '');
end
