function idx = ng_layer_at(z, layers)
%NG_LAYER_AT Index of the soil layer containing depth z [ft].
%
%   idx = ng_layer_at(z, layers)
%
%   Returns the FIRST layer with depth_top <= z <= depth_bot (so a depth
%   exactly at an interface belongs to the layer above, the same
%   convention used for the tip layer in ng_capacity). Errors if z is not
%   covered by the layer stack.

    for k = 1:numel(layers)
        if layers(k).depth_top <= z && z <= layers(k).depth_bot
            idx = k;
            return;
        end
    end
    error('navfac_general:depthNotCovered', ...
        'Depth %.3f ft is not covered by the soil layer stack (0 to %.3f ft).', ...
        z, layers(end).depth_bot);
end
