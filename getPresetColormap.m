function cmap = getPresetColormap(name, n)
% getPresetColormap  Return a ColorKit preset colormap by name or ID.
%
% Author: zhaoyh, 2026.
% Email: zhao2025@mail.sustech.edu.cn
%
% Usage:
%   cmap = getPresetColormap("Blue", 256);
%   cmap = getPresetColormap(13, 256);
%   cmap = getPresetColormap("Set10", 10);
%
% The implementation is intentionally thin so the preset library remains
% centralized in ColorKit.m.

if nargin < 1 || isempty(name)
    name = "Blue";
end
if nargin < 2 || isempty(n)
    n = 256;
end

cmap = ColorKit('palette', name, 'nColors', n, 'preview', false);
end

