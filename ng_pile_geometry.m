function geom = ng_pile_geometry(pile)
%NG_PILE_GEOMETRY Cross-section area and perimeter for round/square piles.
%
%   geom = ng_pile_geometry(pile)
%
%   Inputs (pile struct):
%     shape   : 'round' or 'square'
%     size_in : diameter or width [in]
%     A       : optional override area [in^2]      (e.g. H-pile, hollow pipe)
%     P       : optional override perimeter [in]
%
%   Output (geom struct):
%     D_ft           : diameter/width [ft]
%     A_in2, P_in    : area [in^2], perimeter [in]
%     A_ft2, P_ft    : area [ft^2], perimeter [ft]
%
%   If A or P is provided it is used as-is; the missing one is computed
%   from shape + size_in. (Carried over from reissner/get_pile_geometry.)

    shape = lower(pile.shape);
    s_in  = pile.size_in;

    hasA = isfield(pile, 'A') && ~isempty(pile.A) && all(isfinite(pile.A));
    hasP = isfield(pile, 'P') && ~isempty(pile.P) && all(isfinite(pile.P));
    A_in2 = NaN;  P_in = NaN;
    if hasA, A_in2 = pile.A; end
    if hasP, P_in  = pile.P; end

    switch shape
        case 'round'
            if ~hasA, A_in2 = pi * (s_in/2)^2; end
            if ~hasP, P_in  = pi * s_in;       end
        case 'square'
            if ~hasA, A_in2 = s_in^2;          end
            if ~hasP, P_in  = 4 * s_in;        end
        otherwise
            error('navfac_general:badShape', ...
                'Unsupported pile.shape "%s" (use ''round'' or ''square'', or provide A and P overrides).', ...
                pile.shape);
    end

    if ~(isfinite(A_in2) && A_in2 > 0)
        error('navfac_general:badGeometry', 'Computed/provided pile area is invalid (%.4g in^2).', A_in2);
    end
    if ~(isfinite(P_in) && P_in > 0)
        error('navfac_general:badGeometry', 'Computed/provided pile perimeter is invalid (%.4g in).', P_in);
    end

    geom = struct('shape', shape, 'size_in', s_in, 'D_ft', s_in/12, ...
        'A_in2', A_in2, 'P_in', P_in, 'A_ft2', A_in2/144, 'P_ft', P_in/12);
end
