function Nq = ng_nq_table(phi, pile_type)
%NG_NQ_TABLE NAVFAC DM-7.02 bearing factor Nq (ALLPILE Table 8-1).
%
%   Nq = ng_nq_table(phi, pile_type)
%
%   phi       : friction angle at the pile tip [deg]
%   pile_type : 'displacement' (driven) | 'nondisplacement' (bored)
%
%   Linear interpolation in the published table (phi = 26..40 deg). A phi
%   outside the table range raises a WARNING and is clamped to the nearest
%   table limit - it is never silently extrapolated. Review out-of-range
%   cases (very loose or very dense sand) against project-specific data.

    phit  = [26   28   30   31   32   33   34   35   36   37   38    39    40];
    dispv = [11.0 15.2 21.0 24.6 29.1 34.5 41.3 49.9 60.9 75.0 93.0 116.1 145.4];
    nondv = [ 5.6  7.6 10.3 12.1 14.2 16.9 20.3 24.6 30.1 37.1 46.1  57.7  72.3];

    switch pile_type
        case 'displacement',    tbl = dispv;
        case 'nondisplacement', tbl = nondv;
        otherwise
            error('navfac_general:badPileType', ...
                'pile_type must be ''displacement'' or ''nondisplacement'', got "%s".', pile_type);
    end

    if phi < phit(1) || phi > phit(end)
        phi_clamped = min(max(phi, phit(1)), phit(end));
        warning('navfac_general:NqOutOfRange', ...
            ['phi = %.1f deg is outside the NAVFAC Nq table range (%g-%g deg). ' ...
             'Clamping to %.0f deg (Nq = %.1f, %s) instead of extrapolating - verify this is appropriate.'], ...
            phi, phit(1), phit(end), phi_clamped, ...
            interp1(phit, tbl, phi_clamped, 'linear'), pile_type);
        phi = phi_clamped;
    end

    Nq = interp1(phit, tbl, phi, 'linear');
end
