function metadata = ColorKit_UserMetadata()
% ColorKit_UserMetadata  User-editable metadata overrides.
%
% Author: zhaoyh, 2026.
% Email: zhao2025@mail.sustech.edu.cn
%
% Use ColorKit('set-use', nameOrID, recommendedUse) to update this file.

rows = cell(0, 2);
% <ColorKit_USER_METADATA_BEGIN>
% <ColorKit_USER_METADATA_END>

metadata = struct('name', {}, 'recommendedUse', {});
if isempty(rows)
    return
end
metadata(1, size(rows, 1)) = struct('name', "", 'recommendedUse', "");
for k = 1:size(rows, 1)
    metadata(k) = struct('name', string(rows{k, 1}), ...
        'recommendedUse', string(rows{k, 2}));
end
end

