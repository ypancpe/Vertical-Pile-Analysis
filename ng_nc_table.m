function Nc = ng_nc_table(z_over_B)
%NG_NC_TABLE NAVFAC DM-7.02 bearing factor Nc for clay (ALLPILE Table 8-2).
%
%   Nc = ng_nc_table(z_over_B)
%
%   z_over_B : embedment-to-width ratio at the pile tip [-]
%
%   Skempton-type curve: Nc rises from 6.3 at the surface to 9.0 at
%   z/B >= 4 (deep foundation value). z/B is clamped into [0, inf) -> the
%   curve is flat at 9.0 beyond z/B = 4, so any deep pile gets Nc = 9.0.

    if z_over_B < 0
        error('navfac_general:badZoverB', 'z/B must be >= 0 (got %.3g).', z_over_B);
    end
    zb = [0   1   2   3   4  ];
    nc = [6.3 7.8 8.4 8.8 9.0];
    Nc = interp1(zb, nc, min(z_over_B, zb(end)), 'linear');
end
