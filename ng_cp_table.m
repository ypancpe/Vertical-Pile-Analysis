function Cp = ng_cp_table(soil_type, pile_type)
%NG_CP_TABLE Vesic (1977) tip coefficient Cp (ALLPILE Table 8-3), range midpoints.
%
%   Cp = ng_cp_table(soil_type, pile_type)
%
%   soil_type : 'sand' | 'clay'  (soil at the pile tip)
%   pile_type : 'displacement' (driven) | 'nondisplacement' (bored)
%
%   Published ranges (Vesic 1977; driven = displacement, bored = non-displ.):
%       sand : driven 0.02 - 0.04   bored 0.09 - 0.18
%       clay : driven 0.02 - 0.03   bored 0.03 - 0.06
%       (silt: driven 0.03 - 0.05   bored 0.09 - 0.12 - model silt as the
%        nearer of sand/clay, or set par.Cp explicitly)
%   This helper returns the MIDPOINT of the range; override with par.Cp
%   when project data justify a different value.

    switch [soil_type '/' pile_type]
        case 'sand/displacement',    Cp = 0.030;
        case 'sand/nondisplacement', Cp = 0.135;
        case 'clay/displacement',    Cp = 0.025;
        case 'clay/nondisplacement', Cp = 0.045;
        otherwise
            error('navfac_general:badCpLookup', ...
                'No Cp entry for soil "%s" / pile "%s". Set par.Cp explicitly.', ...
                soil_type, pile_type);
    end
end
