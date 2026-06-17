function [f_down, f_up, info] = ng_unit_side_friction(layer, sigma_v, par)
%NG_UNIT_SIDE_FRICTION Unit side resistance for one layer (NAVFAC DM-7.02).
%
%   [f_down, f_up, info] = ng_unit_side_friction(layer, sigma_v, par)
%
%   layer   : soil layer struct (phi [deg] sand XOR cu [psf] clay)
%   sigma_v : effective vertical stress to use [psf] (caller applies the
%             critical-depth cap by evaluating at min(z, z_crit))
%   par     : analysis parameters (K_down, K_up, Kf, Kc, Ka, f_limit)
%
%   Sand : f = K * sigma_v * tan(delta),  delta = Kf * phi
%          (K = par.K_down for compression, par.K_up for uplift)
%          A layer may set an optional delta_deg field to override Kf*phi
%          with a fixed interface angle - NAVFAC's delta = 20 deg for steel
%          piles in mixed-phi profiles, where no single Kf works.
%   Clay : f = Ca = Kc * Ka * cu          (same value down and up)
%   Both are capped at par.f_limit when it is finite.
%
%   info : struct with soil_type, delta_deg (sand), Ca_psf (clay),
%          f_limited (true if the cap governed either value).
%
%   This single helper is used by BOTH the capacity sum and the Vesic
%   settlement integration, so the two can never drift apart.

    isSand = isfinite(layer.phi) && layer.phi > 0;

    if isSand
        if isfield(layer, 'delta_deg') && ~isempty(layer.delta_deg) ...
                && isfinite(layer.delta_deg)
            delta = layer.delta_deg;                     % [deg] explicit override
        else
            delta = par.Kf * layer.phi;                  % [deg]
        end
        t = tan(deg2rad(delta));
        f_down = par.K_down * sigma_v * t;
        f_up   = par.K_up   * sigma_v * t;
        info = struct('soil_type', 'sand', 'delta_deg', delta, 'Ca_psf', NaN);
    else
        Ca = par.Kc * par.Ka * layer.cu;                 % [psf]
        f_down = Ca;
        f_up   = Ca;
        info = struct('soil_type', 'clay', 'delta_deg', NaN, 'Ca_psf', Ca);
    end

    info.f_limited = false;
    if isfinite(par.f_limit)
        if f_down > par.f_limit || f_up > par.f_limit
            info.f_limited = true;
        end
        f_down = min(f_down, par.f_limit);
        f_up   = min(f_up,   par.f_limit);
    end
end
