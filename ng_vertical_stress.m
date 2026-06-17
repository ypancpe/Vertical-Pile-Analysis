function [sigma_eff, sigma_avg] = ng_vertical_stress(z, layers, WT)
%NG_VERTICAL_STRESS Effective vertical stress profile with buoyancy (vectorized).
%
%   [sigma_eff, sigma_avg] = ng_vertical_stress(z, layers, WT)
%
%   z      : depth(s) below ground surface/mudline [ft], scalar or array
%   layers : contiguous soil layer struct array (depth_top/depth_bot [ft],
%            gamma_above [pcf] used above the water table, gamma_below
%            [pcf, buoyant] used below it)
%   WT     : water-table depth below surface [ft] (0 = at/above surface)
%
%   sigma_eff : effective vertical stress at z [psf]
%   sigma_avg : depth-average of sigma_eff from 0 to z [psf]
%
%   The profile is piecewise linear in z (constant gamma between
%   breakpoints), so interpolating between breakpoints is EXACT - this is
%   the same result as the original per-call accumulation loop in
%   reissner/navfac, just evaluated for any number of depths at once.
%   Depths below the deepest layer reuse the stress at the layer-stack
%   bottom (same hold-constant behavior as the original).

    ztop = [layers.depth_top];
    zbot = [layers.depth_bot];

    % breakpoints: every layer boundary plus the water table (if inside)
    pts = unique([ztop, zbot, WT]);
    pts = pts(pts >= ztop(1) & pts <= zbot(end));
    nseg = numel(pts) - 1;

    % cumulative stress and cumulative integral of stress at breakpoints
    sig = zeros(1, nseg + 1);
    I   = zeros(1, nseg + 1);
    for k = 1:nseg
        zmid = 0.5 * (pts(k) + pts(k+1));
        idx = find(ztop <= zmid & zmid < zbot, 1, 'first');
        if isempty(idx), idx = numel(layers); end
        if zmid < WT
            g = layers(idx).gamma_above;
        else
            g = layers(idx).gamma_below;
        end
        sig(k+1) = sig(k) + g * (pts(k+1) - pts(k));
        I(k+1)   = I(k) + 0.5 * (sig(k) + sig(k+1)) * (pts(k+1) - pts(k));
    end

    % evaluate (clamp into the profile; hold constant below the stack)
    zq = min(max(z, 0), pts(end));
    sigma_eff = reshape(interp1(pts, sig, zq(:)), size(z));

    if nargout > 1
        K = sum(bsxfun(@ge, zq(:), pts(2:end)), 2) + 1;   % segment index per query
        K = min(max(K, 1), nseg);
        I_at = I(K)' + 0.5 * (sig(K)' + sigma_eff(:)) .* (zq(:) - pts(K)');
        zcol = z(:);                                      % column, whatever shape z has
        I_at = I_at + sig(end) * max(zcol - pts(end), 0); % held-constant tail below stack
        sigma_avg = zeros(size(z));
        pos = zcol > 0;
        tmp = zeros(numel(zq), 1);
        tmp(pos) = I_at(pos) ./ zcol(pos);                % divide by TRUE depth
        sigma_avg(:) = tmp;
    end
end
