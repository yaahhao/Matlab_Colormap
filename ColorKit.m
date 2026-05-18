function varargout = ColorKit(action, varargin)
% ColorKit - MATLAB colormap and palette toolkit for research figures.
%
% Author: zhaoyh, 2026.
% Email: zhao2025@mail.sustech.edu.cn
%
% Recommended API:
%   C = ColorKit('palette', 'Blue', 'nColors', 256, 'preview', true);
%   C = ColorKit('ramp', 'BlueWhiteRed', 'nColors', 256, 'preview', true);
%   C = ColorKit('pick', 'preview', true);
%   C = ColorKit('imagebar', 'samples', 10, 'nColors', 256, 'preview', true);
%   C = ColorKit('theme-grid', 8, 'preview', true);
%   C = ColorKit('theme-cluster', 8, 'preview', true);
%   row = ColorKit('add-preset', C, 'presetName', 'My_Colors');
%   row = ColorKit('set-use', 'My_Colors', 'temperature map');
%   ColorKit('cards', 'Blue', 'nColors', 256);
%   catalog = ColorKit('catalog');
%   matches = ColorKit('search', 'blue');
%   summary = ColorKit('about');
%
% Copyright (c) 2026 zhaoyh. All rights reserved.
%
% This single-file toolkit intentionally avoids the older online example
% names. The palette library, image color sampling, card browser, and
% plotting helpers live in this file.

if nargin == 0
    showColorHelp();
    return
end

action = lower(strtrim(char(action)));
if strcmp(action, '__selftest__')
    runColorSelfTests();
    if nargout > 0
        varargout{1} = true;
    end
    return
end

switch action
    case {'palette', 'scheme'}
        [output, meta] = callColorPalette(varargin);
    case {'ramp', 'gradient'}
        [output, meta] = callColorRamp(varargin);
    case {'pick', 'sample-image'}
        [output, meta] = callColorPick(varargin);
    case {'imagebar', 'barline', 'sample-bar'}
        [output, meta] = callColorImageBar(varargin);
    case {'theme-grid', 'theme-quantized'}
        [output, meta] = callColorTheme(varargin, 'img2palette1');
    case {'theme-cluster', 'theme-kmeans'}
        [output, meta] = callColorTheme(varargin, 'img2palette2');
    case {'cards', 'browse'}
        [output, meta] = callColorCards(varargin);
    case {'add-preset', 'save-preset'}
        [output, meta] = callColorAddPreset(varargin);
    case {'set-use', 'update-use', 'recommended-use', 'set-recommended-use'}
        [output, meta] = callColorSetRecommendedUse(varargin);
    case {'search', 'find'}
        [output, meta] = callColorSearch(varargin);
    case {'categories', 'groups'}
        output = presetCategories();
        meta = struct('Action', 'categories', 'Total', numel(output));
    case {'catalog', 'library'}
        output = presetCatalogTable(buildPresetLibrary());
        meta = struct('Action', 'catalog', 'Total', height(output));
    case {'about', 'summary'}
        output = presetSummaryTable(buildPresetLibrary());
        meta = struct('Action', 'about');
    otherwise
        error('ColorKit:UnknownAction', ...
            'Unknown action "%s". Run ColorKit with no inputs for help.', action);
end

if nargout == 0
    if istable(output)
        disp(output);
    end
else
    varargout{1} = output;
    if nargout > 1
        varargout{2} = meta;
    end
end
end

function runColorSelfTests()
fprintf('Running ColorKit self-tests...\n');

c1 = ColorKit('palette', 'Blue', 'preview', false);
assert(size(c1, 2) == 3 && size(c1, 1) >= 2, 'palette must return N-by-3 RGB.');

c2 = ColorKit('palette', 'Viridis', 'nColors', 256, 'preview', false);
assert(isequal(size(c2), [256 3]), 'palette nColors must return requested length.');

c3 = ColorKit('ramp', 'BlueYellow', 'nColors', 10, 'preview', false);
assert(isequal(size(c3), [10 3]), 'ramp nColors must return requested length.');
paletteRamp = ColorKit('palette', 'BlueWhiteRed', 'nColors', 256, 'preview', false);
aliasRamp = ColorKit('ramp', 'BlueWhiteRed', 'nColors', 256, 'preview', false);
assert(max(abs(paletteRamp(:) - aliasRamp(:))) < 1e-12, ...
    'ramp must be an alias for palette(id, nColors).');

wrapperRamp = getPresetColormap('BlueWhiteRed', 256);
assert(max(abs(paletteRamp(:) - wrapperRamp(:))) < 1e-12, ...
    'getPresetColormap must match ColorKit palette output.');

img = zeros(24, 36, 3);
img(:, 1:12, 1) = 1;
img(:, 13:24, 2) = 1;
img(:, 25:36, 3) = 1;
picked = ColorKit('pick', img, 'points', [6 12; 18 12; 30 12], 'preview', false);
assert(isequal(size(picked), [3 3]), 'pick must sample requested points.');

barImg = repmat(reshape(linspace(0, 1, 50), 1, [], 1), 10, 1, 3);
barMap = ColorKit('imagebar', 5, barImg, 'endpoints', [1 5; 50 5], ...
    'nColors', 11, 'preview', false);
assert(isequal(size(barMap), [11 3]), 'imagebar must support densification.');
barMapByOption = ColorKit('imagebar', barImg, 'samples', 5, ...
    'endpoints', [1 5; 50 5], 'nColors', 11, 'preview', false);
assert(max(abs(barMap(:) - barMapByOption(:))) < 1e-12, ...
    'imagebar samples option must match positional sample count.');

gridTheme = ColorKit('theme-grid', 3, img, 'preview', false);
clusterTheme = ColorKit('theme-cluster', 3, img, 'preview', false);
assert(isequal(size(gridTheme), [3 3]), 'theme-grid must return requested colors.');
assert(isequal(size(clusterTheme), [3 3]), 'theme-cluster must return requested colors.');

catalog = ColorKit('catalog');
assert(istable(catalog) && height(catalog) <= 300, 'catalog must expose no more than 300 palettes.');
assert(numel(unique(catalog.Name)) == height(catalog), 'catalog names must be unique.');
expectedGroups = ["All"; "Built-in"; "Sequential"; "Diverging"; ...
    "Categorical"; "Cyclic"; "Grayscale"; "Custom"];
actualGroups = ColorKit('categories');
assert(isequal(string(actualGroups(:)), expectedGroups), 'palette groups must use the compact public group list.');
assert(ismember('PaletteGroup', catalog.Properties.VariableNames), 'catalog must expose PaletteGroup.');
assert(~ismember('Category', catalog.Properties.VariableNames), 'catalog must not expose Category.');
builtInRows = catalog.ID <= 100;
assert(nnz(builtInRows) >= 80 && nnz(builtInRows) <= 100, ...
    'built-in catalog must stay near 80-100 palettes.');
blockedTokens = ["Nature", "Special", "_like", "Crameri", "cmocean", ...
    "ColorBrewer", "DAS", "FK", "PSD", "Geophysical", "Thermal"];
blockedHits = false(size(catalog.Name));
lowerNames = lower(catalog.Name);
for k = 1:numel(blockedTokens)
    blockedHits = blockedHits | contains(lowerNames, lower(blockedTokens(k)));
end
assert(~any(blockedHits & builtInRows), 'built-in public names must stay neutral.');
assert(strcmp(normalizePaletteGroup("none"), "Custom"), 'none group must normalize to Custom.');
assert(strcmp(normalizePaletteGroup("Sequential"), "Sequential"), 'known groups must be preserved.');
assert(strcmp(normalizePaletteGroup("MyGroup"), "MyGroup"), 'custom group names must be preserved.');
try
    oldName = "N" + "ature" + "_" + "Blue";
    ColorKit('palette', oldName, 'preview', false);
    error('ColorKit:SelfTestExpectedFailure', 'old names must not resolve.');
catch err
    assert(strcmp(err.identifier, 'ColorKit:UnknownPreset'), 'old names must fail as unknown presets.');
end
matches = ColorKit('search', 'blue');
assert(istable(matches) && height(matches) > 0, 'search must find blue palettes.');
catLong = ColorKit('palette', 'Set10', 'nColors', 32, 'preview', false);
assert(isequal(size(catLong), [32 3]), 'categorical palettes must expand to requested length.');
assert(any(sqrt(sum(diff(catLong) .^ 2, 2)) > 1e-8), ...
    'expanded categorical palette must not be a flat repeated color.');

oldVisible = get(groot, 'defaultFigureVisible');
set(groot, 'defaultFigureVisible', 'off');
cleanupObj = onCleanup(@() set(groot, 'defaultFigureVisible', oldVisible));
fig = ColorKit('cards', 'Sequential', 1, 4, 'visible', false);
assert(isvalid(fig), 'cards must return a valid figure.');
delete(fig);
clear cleanupObj

fprintf('ColorKit self-tests passed.\n');
end

function [cmap, meta] = callColorPalette(args)
[presetRef, args] = popColorLeadingPreset(args, "Blue");
opts = parseColorUserOptions(args);
[cmap, preset, id] = presetColormapByRef(presetRef, opts.NColors);
if opts.Preview
    showPalette(cmap, sprintf('%s (%d colors)', preset.name, size(cmap, 1)), ...
        strcmpi(preset.type, "qualitative"));
end
meta = struct('Action', 'palette', 'ID', id, 'Name', preset.name, ...
    'PaletteGroup', paletteGroupForPreset(preset), ...
    'Type', preset.type, 'NColors', size(cmap, 1), ...
    'Source', preset.sourceStyle);
end

function [cmap, meta] = callColorRamp(args)
[presetRef, args] = popColorLeadingPreset(args, "Blue");
opts = parseColorUserOptions(args);
targetN = opts.NColors;
if isempty(targetN)
    targetN = 256;
end
[cmap, preset, id] = presetColormapByRef(presetRef, targetN);
if opts.Preview
    showPalette(cmap, sprintf('%s ramp (%d colors)', preset.name, size(cmap, 1)), false);
end
meta = struct('Action', 'ramp', 'ID', id, 'Name', preset.name, ...
    'PaletteGroup', paletteGroupForPreset(preset), ...
    'Type', preset.type, 'NColors', size(cmap, 1), ...
    'Source', preset.sourceStyle);
end

function [cmap, meta] = callColorPick(args)
[imageInput, args] = popColorLeadingImage(args);
opts = parseColorUserOptions(args);
callArgs = {'copy'};
if ~isempty(imageInput)
    callArgs{end + 1} = imageInput;
end
if ~isempty(opts.Points)
    callArgs = [callArgs, {'points', opts.Points}];
end
if ~isempty(opts.NColors)
    callArgs = [callArgs, {'map', opts.NColors}];
end
callArgs = [callArgs, {'seka', double(opts.Preview)}];
[cmap, engineInfo] = colorEngine(callArgs{:});
meta = struct('Action', 'pick', 'NColors', size(cmap, 1), ...
    'Meaning', 'Sample RGB colors from imported image pixels.');
if isfield(engineInfo, 'Points')
    meta.Points = engineInfo.Points;
end
if isfield(engineInfo, 'Source')
    meta.Source = engineInfo.Source;
end
end

function [cmap, meta] = callColorImageBar(args)
[sampleCount, args] = popColorLeadingNumber(args, 10);
[imageInput, args] = popColorLeadingImage(args);
opts = parseColorUserOptions(args);
if ~isempty(opts.SampleCount)
    sampleCount = opts.SampleCount;
end
callArgs = {'copymap', sampleCount};
if ~isempty(imageInput)
    callArgs{end + 1} = imageInput;
end
if ~isempty(opts.Endpoints)
    callArgs = [callArgs, {'endpoints', opts.Endpoints}];
end
if ~isempty(opts.NColors)
    callArgs = [callArgs, {'map', opts.NColors}];
end
callArgs = [callArgs, {'seka', double(opts.Preview)}];
[cmap, engineInfo] = colorEngine(callArgs{:});
meta = struct('Action', 'imagebar', 'Samples', sampleCount, ...
    'NColors', size(cmap, 1), 'Meaning', 'Sample an image colorbar along its first and last points.');
if isfield(engineInfo, 'Endpoints')
    meta.Endpoints = engineInfo.Endpoints;
end
if isfield(engineInfo, 'SampleLength')
    meta.SampleLength = engineInfo.SampleLength;
end
end

function [cmap, meta] = callColorTheme(args, legacyMode)
[count, args] = popColorLeadingNumber(args, 8);
[imageInput, args] = popColorLeadingImage(args);
opts = parseColorUserOptions(args);
callArgs = {legacyMode, count};
if ~isempty(imageInput)
    callArgs{end + 1} = imageInput;
end
callArgs = [callArgs, {'seka', double(opts.Preview)}];
cmap = colorEngine(callArgs{:});
meta = struct('Action', legacyMode, 'NColors', size(cmap, 1), ...
    'Meaning', 'Extract dominant theme colors from an imported image.');
end

function [fig, meta] = callColorCards(args)
[fig, info] = presetCardsFigure(args);
meta = info;
meta.Action = 'cards';
end

function [row, meta] = callColorAddPreset(args)
if isempty(args) || ~isnumeric(args{1}) || size(args{1}, 2) ~= 3
    error('ColorKit:AddPresetInput', ...
        'First input must be an N-by-3 RGB colormap.');
end
cmap = cleanCmap(args{1});
opts = parseColorUserOptions(args(2:end));
[row, appendInfo] = appendUserPreset(cmap, opts);
meta = appendInfo;
end

function [row, meta] = callColorSetRecommendedUse(args)
if numel(args) < 2
    error('ColorKit:SetUseInput', ...
        'Usage: ColorKit(''set-use'', presetNameOrID, recommendedUse).');
end
presetRef = args{1};
if (ischar(args{2}) || isstring(args{2})) && isColorOptionKey(args{2})
    opts = parseColorUserOptions(args(2:end));
    recommendedUse = string(opts.RecommendedUse);
else
    recommendedUse = string(args{2});
end

presets = buildPresetLibrary();
[preset, id] = resolvePreset(presets, presetRef);
targetFile = ensureUserMetadataFile();
overrides = loadUserMetadataOverrides();
overrides = upsertRecommendedUseOverride(overrides, preset.name, recommendedUse);
writeUserMetadataOverrides(targetFile, overrides);

catalog = presetCatalogTable(buildPresetLibrary());
row = catalog(id, :);
meta = struct('Action', 'set-use', 'ID', id, 'Name', preset.name, ...
    'RecommendedUse', recommendedUse, 'File', targetFile);
end

function [matches, meta] = callColorSearch(args)
keyword = "";
if ~isempty(args) && (ischar(args{1}) || isstring(args{1}))
    keyword = string(args{1});
end
matches = searchPresetCatalog(keyword);
meta = struct('Action', 'search', 'Keyword', keyword, 'Total', height(matches));
end

function opts = parseColorUserOptions(args)
opts = struct('NColors', [], 'Preview', false, 'Points', [], 'Endpoints', [], ...
    'SampleCount', [], ...
    'Columns', 4, 'Visible', true, 'SaveFile', '', ...
    'PresetName', "", 'PresetCategory', "none", 'PresetType', "none", ...
    'RecommendedUse', "none", 'IsColorblindFriendly', "none", ...
    'IsPrintFriendly', "none", 'CenterColor', "none", 'SourceStyle', "none");

i = 1;
while i <= numel(args)
    key = args{i};
    if ischar(key) || isstring(key)
        keyText = lower(strtrim(char(key)));
        switch keyText
            case {'ncolors', 'colors', 'length', 'n'}
                [opts.NColors, i] = readColorValue(args, i, 256);
                opts.NColors = normalizeColorCount(opts.NColors, 2, 4096);
            case {'preview', 'show'}
                [opts.Preview, i] = readColorValue(args, i, true);
                opts.Preview = logicalColorScalar(opts.Preview);
            case {'points', 'xy'}
                [opts.Points, i] = readColorValue(args, i, []);
                opts.Points = normalizeColorPoints(opts.Points);
            case {'endpoints', 'line'}
                [opts.Endpoints, i] = readColorValue(args, i, []);
                opts.Endpoints = normalizeColorPoints(opts.Endpoints);
            case {'samples', 'samplecount', 'nsamples', 'anchors'}
                [opts.SampleCount, i] = readColorValue(args, i, 10);
                opts.SampleCount = normalizeColorCount(opts.SampleCount, 2, 4096);
            case {'columns', 'cols'}
                [opts.Columns, i] = readColorValue(args, i, 4);
                opts.Columns = normalizeColorCount(opts.Columns, 1, 8);
            case {'visible'}
                [opts.Visible, i] = readColorValue(args, i, true);
                opts.Visible = logicalColorScalar(opts.Visible);
            case {'saveas', 'savefile', 'exportfile'}
                [opts.SaveFile, i] = readColorValue(args, i, '');
                opts.SaveFile = char(string(opts.SaveFile));
            case {'presetname', 'name'}
                [opts.PresetName, i] = readColorValue(args, i, "");
                opts.PresetName = string(opts.PresetName);
            case {'palettegroup', 'group', 'category', 'presetcategory'}
                [opts.PresetCategory, i] = readColorValue(args, i, "none");
                opts.PresetCategory = string(opts.PresetCategory);
            case {'type', 'presettype'}
                [opts.PresetType, i] = readColorValue(args, i, "none");
                opts.PresetType = string(opts.PresetType);
            case {'recommendeduse', 'use'}
                [opts.RecommendedUse, i] = readColorValue(args, i, "none");
                opts.RecommendedUse = string(opts.RecommendedUse);
            case {'iscolorblindfriendly', 'colorblindfriendly', 'colorblind'}
                [opts.IsColorblindFriendly, i] = readColorValue(args, i, "none");
                opts.IsColorblindFriendly = string(opts.IsColorblindFriendly);
            case {'isprintfriendly', 'printfriendly', 'print'}
                [opts.IsPrintFriendly, i] = readColorValue(args, i, "none");
                opts.IsPrintFriendly = string(opts.IsPrintFriendly);
            case {'centercolor', 'center'}
                [opts.CenterColor, i] = readColorValue(args, i, "none");
                opts.CenterColor = string(opts.CenterColor);
            case {'sourcestyle', 'source'}
                [opts.SourceStyle, i] = readColorValue(args, i, "none");
                opts.SourceStyle = string(opts.SourceStyle);
            otherwise
                i = i + 1;
        end
    else
        i = i + 1;
    end
end
end

function [value, nextIndex] = readColorValue(args, keyIndex, defaultValue)
if keyIndex + 1 <= numel(args)
    value = args{keyIndex + 1};
    nextIndex = keyIndex + 2;
else
    value = defaultValue;
    nextIndex = keyIndex + 1;
end
end

function [value, args] = popColorLeadingNumber(args, defaultValue)
value = defaultValue;
if ~isempty(args) && isnumeric(args{1}) && isscalar(args{1})
    value = args{1};
    args = args(2:end);
elseif ~isempty(args) && (ischar(args{1}) || isstring(args{1}))
    candidate = str2double(args{1});
    if isfinite(candidate)
        value = candidate;
        args = args(2:end);
    end
end
end

function [imageInput, args] = popColorLeadingImage(args)
imageInput = [];
if isempty(args)
    return
end
candidate = args{1};
if isnumeric(candidate) && ndims(candidate) >= 2 && ~isscalar(candidate)
    imageInput = candidate;
    args = args(2:end);
elseif ischar(candidate) || isstring(candidate)
    text = char(candidate);
    if exist(text, 'file') == 2
        imageInput = text;
        args = args(2:end);
    end
end
end

function [family, args] = popColorLeadingFamily(args, defaultFamily)
family = defaultFamily;
if isempty(args) || ~(ischar(args{1}) || isstring(args{1}))
    return
end
candidate = lower(strtrim(char(args{1})));
if any(strcmp(candidate, {'palette', 'ramp'}))
    family = candidate;
    args = args(2:end);
end
end

function engineFamily = familyToEngine(~)
engineFamily = 'palette';
end

function text = colorPaletteSourceText(id)
presets = buildPresetLibrary();
id = max(1, min(numel(presets), round(double(id))));
text = char(presets(id).sourceStyle + ": " + presets(id).recommendedUse);
end

function [presetRef, args] = popColorLeadingPreset(args, defaultValue)
presetRef = defaultValue;
if isempty(args)
    return
end
candidate = args{1};
if isnumeric(candidate) && isscalar(candidate)
    presetRef = candidate;
    args = args(2:end);
elseif ischar(candidate) || isstring(candidate)
    text = string(candidate);
    if ~isColorOptionKey(text)
        presetRef = text;
        args = args(2:end);
    end
end
end

function tf = isColorOptionKey(value)
value = lower(strtrim(string(value)));
keys = ["ncolors", "colors", "length", "n", "preview", "show", ...
    "points", "xy", "endpoints", "line", "columns", "cols", ...
    "samples", "samplecount", "nsamples", "anchors", ...
    "visible", "saveas", "savefile", "exportfile", ...
    "presetname", "name", "palettegroup", "group", "category", ...
    "presetcategory", "type", "presettype", "recommendeduse", "use", ...
    "iscolorblindfriendly", "colorblindfriendly", "colorblind", ...
    "isprintfriendly", "printfriendly", "print", "centercolor", ...
    "center", "sourcestyle", "source"];
tf = any(value == keys);
end

function [cmap, preset, id] = presetColormapByRef(presetRef, n)
presets = buildPresetLibrary();
[preset, id] = resolvePreset(presets, presetRef);
cmap = presetToColormap(preset, n);
end

function presets = buildPresetLibrary()
% buildPresetLibrary returns the curated ColorKit palette library.
%
% Sequential palettes are for one-way scalar variables. Diverging palettes
% are for centered or positive-negative data. Cyclic palettes are for
% phase, azimuth, orientation, and wrapped variables. Categorical palettes
% are for classes. Jet/rainbow-style palettes are
% included only for compatibility and are not recommended as defaults for
% quantitative continuous data because they can create false visual edges.
template = struct('name', "", 'category', "", 'type', "", ...
    'anchors', strings(1, 0), 'recommendedUse', "", ...
    'isColorblindFriendly', "approximate", 'isPrintFriendly', "approximate", ...
    'centerColor', "", 'sourceStyle', "", 'matlabName', "", 'nativeN', []);
presets = template([]);

builtins = ["parula", "turbo", "jet", "hot", "cool", "gray", ...
    "bone", "copper", "pink", "hsv", "lines", "white"];
for k = 1:numel(builtins)
    typeValue = "sequential";
    cb = "approximate";
    printValue = "approximate";
    useValue = "none";
    if builtins(k) == "lines"
        typeValue = "qualitative";
    elseif builtins(k) == "hsv"
        typeValue = "cyclic";
        cb = "false";
    elseif builtins(k) == "jet"
        cb = "false";
    end
    presets = addPreset(presets, builtins(k), "Built-in", typeValue, ...
        strings(1, 0), useValue, cb, printValue, "", "MATLAB", builtins(k), 256);
end

presets = addPresetRows(presets, "Sequential", "sequential", ...
    "internal", "none", { ...
    "Blue", ["#F7FBFF" "#DCEAF6" "#9DC7E0" "#4F93C2" "#155D8B" "#08304F"]; ...
    "DeepBlue", ["#F4F8FB" "#C9DCEB" "#7AA7C7" "#2F6F9F" "#123D63" "#061E36"]; ...
    "BlueGray", ["#F8F9FA" "#DDE5EA" "#B3C6D3" "#7897AB" "#3F647A" "#203949"]; ...
    "CyanBlue", ["#F2FCFC" "#C7ECEA" "#7ECAC8" "#3499AE" "#12678C" "#083B5C"]; ...
    "Green", ["#F7FCF5" "#D9F0D3" "#A6DBA0" "#5AAE61" "#238B45" "#005A32"]; ...
    "GreenBlue", ["#F6FCF8" "#CDECE2" "#8DD3C7" "#43A2CA" "#0868AC" "#084081"]; ...
    "Teal", ["#F3FBF9" "#CDEBE5" "#8DD3C7" "#3BA99C" "#087F78" "#04514D"]; ...
    "Purple", ["#FCFBFD" "#E6E1F2" "#C2B8DF" "#8D76BF" "#5E3C99" "#33175A"]; ...
    "PurpleBlue", ["#FCFBFD" "#D8D8EE" "#A9B8D9" "#6C93C4" "#2B6CA3" "#163E73"]; ...
    "Rose", ["#FFF7F8" "#FADADD" "#F2A7B5" "#D66A7C" "#A9364F" "#6B1830"]; ...
    "Orange", ["#FFF8EF" "#FDE2B8" "#F9BE6B" "#E8892E" "#B95C13" "#74320B"]; ...
    "Amber", ["#FFFBEF" "#F9E9AE" "#E7C861" "#C99B2E" "#8A6614" "#4C3507"]; ...
    "Brown", ["#FAF7F2" "#E5D5C3" "#C0A389" "#8F6B4F" "#5A3A2A" "#2E1C14"]; ...
    "Slate", ["#F7F9FA" "#D9E1E6" "#AAB9C3" "#708899" "#3D5466" "#1F2D3A"]; ...
    "LowSatWarm", ["#FAF8F2" "#E8DCC9" "#D0B79B" "#B58E6E" "#8D6049" "#513529"]; ...
    "LowSatCool", ["#F6F8F9" "#D7E1E3" "#AFC7C8" "#78A6A8" "#3F7E83" "#1D4D55"]; ...
    "LowSatNeutral", ["#FAFAF8" "#E7E2D7" "#CDC3B5" "#AFA190" "#827465" "#4A4038"]; ...
    "Ocean", ["#F3FBFF" "#CFEAF5" "#8BC9E0" "#3C9BC2" "#0B6FA4" "#06415F"]; ...
    "Forest", ["#F7FBF4" "#DCEFD4" "#AED6A3" "#6EAD72" "#2C7A4B" "#0B3D2E"]; ...
    "Desert", ["#FFF9EA" "#F2D7A0" "#D9A65A" "#AD7433" "#70451E" "#3B2112"]; ...
    "Ice", ["#FBFEFF" "#E1F3F7" "#B7DDE8" "#7CB7D0" "#3D85A8" "#15516F"]; ...
    "Mist", ["#FAFBFB" "#E4ECEC" "#C6D7D8" "#9AB8BD" "#6D929B" "#3F6570"]; ...
    "Ink", ["#F8F8F7" "#D7D8D9" "#A8ADB3" "#6F7A86" "#354250" "#111820"]; ...
    "Viridis", ["#440154" "#3B528B" "#21918C" "#5EC962" "#FDE725"]; ...
    "Plasma", ["#0D0887" "#6A00A8" "#B12A90" "#E16462" "#FCA636" "#F0F921"]; ...
    "Inferno", ["#000004" "#1B0C41" "#4A0C6B" "#BB3754" "#ED6925" "#FCFFA4"]; ...
    "Magma", ["#000004" "#2C115F" "#721F81" "#B73779" "#F1605D" "#FCFDBF"]; ...
    "Cividis", ["#00224E" "#123570" "#575D6D" "#8A8678" "#C3B369" "#FDE737"]; ...
    "Mako", ["#0B0405" "#243B53" "#28666E" "#5AA7A7" "#BFE3DC"]; ...
    "Rocket", ["#03051A" "#3F1B43" "#8C2D5A" "#D6546A" "#F6B48F" "#FAEBDD"]; ...
    "Blues", ["#F7FBFF" "#C6DBEF" "#6BAED6" "#2171B5" "#08306B"]; ...
    "Greens", ["#F7FCF5" "#C7E9C0" "#74C476" "#238B45" "#00441B"]; ...
    "Oranges", ["#FFF5EB" "#FDD0A2" "#FDAE6B" "#E6550D" "#7F2704"]; ...
    "Purples", ["#FCFBFD" "#DADAEB" "#9E9AC8" "#6A51A3" "#3F007D"]; ...
    "Reds", ["#FFF5F0" "#FCBBA1" "#FB6A4A" "#CB181D" "#67000D"]; ...
    "BlueYellow", ["#061B33" "#0B4F8A" "#1F9BB4" "#A9D46A" "#FDE725"]; ...
    "BlueGreenYellow", ["#08306B" "#2171B5" "#41B6C4" "#7FCDBB" "#C7E9B4" "#FFFFCC"]; ...
    "YlGnBu", ["#FFFFD9" "#C7E9B4" "#41B6C4" "#2C7FB8" "#081D58"]; ...
    "YlOrRd", ["#FFFFCC" "#FED976" "#FD8D3C" "#E31A1C" "#800026"]});

presets = addPresetRows(presets, "Diverging", "diverging", ...
    "internal", "none", { ...
    "BlueWhiteRed", ["#2166AC" "#67A9CF" "#F7F7F7" "#EF8A62" "#B2182B"]; ...
    "BlueWhiteOrange", ["#1F5A8A" "#7FB3D5" "#F8F7F2" "#F3A65A" "#B85C1D"]; ...
    "BlueWhiteBrown", ["#174A7C" "#8BB8D8" "#F7F7F2" "#B9926A" "#5B341E"]; ...
    "CyanWhiteRed", ["#0B7285" "#7BCBD4" "#F8F8F6" "#F18F7B" "#B22234"]; ...
    "TealWhiteRose", ["#006D77" "#83C5BE" "#F8F7F5" "#E598A5" "#9D2042"]; ...
    "PurpleWhiteGreen", ["#5E3C99" "#B2ABD2" "#F7F7F7" "#A6DBA0" "#1B7837"]; ...
    "PurpleWhiteOrange", ["#542788" "#B2ABD2" "#F7F7F7" "#FDB863" "#B35806"]; ...
    "BrownWhiteBlue", ["#7F3B08" "#D8B365" "#F6F6F2" "#80CDC1" "#018571"]; ...
    "NavyWhiteBurgundy", ["#0B2545" "#4F83B5" "#F7F7F7" "#C76F76" "#6D1E33"]; ...
    "GrayWhiteRed", ["#3F3F46" "#A1A1AA" "#F8F8F8" "#F08A80" "#B91C1C"]; ...
    "SlateWhiteAmber", ["#263746" "#8797A5" "#F8F7F2" "#E8B052" "#9A5B0A"]; ...
    "GreenWhiteMagenta", ["#1B7837" "#A6DBA0" "#F7F7F7" "#C2A5CF" "#762A83"]; ...
    "DarkBlueWhiteDarkRed", ["#08306B" "#6BAED6" "#F7F7F7" "#FB6A4A" "#67000D"]; ...
    "CoolWarm", ["#3B4CC0" "#8DB0FE" "#F7F7F7" "#F4987A" "#B40426"]; ...
    "MutedBlueRed", ["#2C4C7C" "#9DBAD7" "#F7F7F7" "#E6A08C" "#8F2D2D"]; ...
    "BalanceSoft", ["#35647A" "#A5C6CC" "#F5F3EB" "#D7B07A" "#8A4B2A"]; ...
    "BlueCreamRose", ["#2F5D8C" "#A7C7DE" "#F7F7F7" "#E7A1A1" "#8C2D4A"]; ...
    "MutedBlueCreamRed", ["#355C7D" "#A6BFD1" "#F7F7F4" "#E0A08D" "#8E3B46"]; ...
    "BrBG", ["#543005" "#BF812D" "#F6E8C3" "#C7EAE5" "#35978F" "#003C30"]; ...
    "PiYG", ["#8E0152" "#DE77AE" "#F7F7F7" "#B8E186" "#276419"]; ...
    "PRGn", ["#40004B" "#9970AB" "#F7F7F7" "#A6DBA0" "#00441B"]; ...
    "PuOr", ["#7F3B08" "#FDB863" "#F7F7F7" "#B2ABD2" "#2D004B"]; ...
    "RdBu", ["#67001F" "#D6604D" "#F7F7F7" "#4393C3" "#053061"]; ...
    "RdGy", ["#67001F" "#D6604D" "#FFFFFF" "#BDBDBD" "#1A1A1A"]; ...
    "RdYlBu", ["#A50026" "#F46D43" "#FFFFBF" "#74ADD1" "#313695"]}, "#F7F7F7");

presets = addPresetRows(presets, "Categorical", "qualitative", ...
    "internal", "none", { ...
    "Set10", ["#1F77B4" "#FF7F0E" "#2CA02C" "#D62728" "#9467BD" "#8C564B" "#E377C2" "#7F7F7F" "#BCBD22" "#17BECF"]; ...
    "Set12", ["#2F4858" "#33658A" "#86BBD8" "#F6AE2D" "#F26419" "#5B8E7D" "#BC4B51" "#6D597A" "#B56576" "#355070" "#A7C957" "#6A994E"]; ...
    "Set20", ["#4E79A7" "#F28E2B" "#E15759" "#76B7B2" "#59A14F" "#EDC948" "#B07AA1" "#FF9DA7" "#9C755F" "#BAB0AC" "#1B9E77" "#D95F02" "#7570B3" "#E7298A" "#66A61E" "#E6AB02" "#A6761D" "#666666" "#A6CEE3" "#B2DF8A"]; ...
    "Muted8", ["#386FA4" "#59A14F" "#E5A65E" "#B56576" "#6D597A" "#84A59D" "#9A8C98" "#BC6C25"]; ...
    "Bright8", ["#0072B2" "#E69F00" "#009E73" "#D55E00" "#CC79A7" "#56B4E9" "#F0E442" "#000000"]; ...
    "Pastel8", ["#A6CEE3" "#B2DF8A" "#FDBF6F" "#CAB2D6" "#FB9A99" "#FFFF99" "#BFD3C1" "#D9BF77"]; ...
    "Dark8", ["#0B132B" "#1C2541" "#3A506B" "#5BC0BE" "#6D597A" "#355070" "#5F0F40" "#0F4C5C"]; ...
    "Earth8", ["#264653" "#2A9D8F" "#E9C46A" "#F4A261" "#E76F51" "#8D6E63" "#6B705C" "#CB997E"]; ...
    "WarmCool8", ["#2C7BB6" "#00A6CA" "#00CCBC" "#90EB9D" "#FFFF8C" "#F9D057" "#F29E2E" "#D7191C"]; ...
    "OkabeIto", ["#000000" "#E69F00" "#56B4E9" "#009E73" "#F0E442" "#0072B2" "#D55E00" "#CC79A7"]; ...
    "Colorblind8", ["#000000" "#E69F00" "#56B4E9" "#009E73" "#F0E442" "#0072B2" "#D55E00" "#CC79A7"]; ...
    "Colorblind12", ["#000000" "#E69F00" "#56B4E9" "#009E73" "#F0E442" "#0072B2" "#D55E00" "#CC79A7" "#999999" "#882255" "#44AA99" "#DDCC77"]; ...
    "Line6", ["#2F4858" "#33658A" "#F6AE2D" "#F26419" "#5B8E7D" "#BC4B51"]; ...
    "Line8", ["#2F4858" "#33658A" "#86BBD8" "#F6AE2D" "#F26419" "#5B8E7D" "#BC4B51" "#6D597A"]; ...
    "Line10", ["#2F4858" "#33658A" "#86BBD8" "#F6AE2D" "#F26419" "#5B8E7D" "#BC4B51" "#6D597A" "#B56576" "#355070"]; ...
    "BlueRed8", ["#1F77B4" "#D62728" "#2CA02C" "#9467BD" "#FF7F0E" "#17BECF" "#8C564B" "#7F7F7F"]});

presets = addPresetRows(presets, "Cyclic", "cyclic", ...
    "internal", "none", { ...
    "PhaseHSV", ["#FF0000" "#FFFF00" "#00FF00" "#00FFFF" "#0000FF" "#FF00FF" "#FF0000"]; ...
    "Twilight", ["#E2D9E6" "#8E7CC3" "#4C72B0" "#55A868" "#E5C07B" "#C44E52" "#E2D9E6"]; ...
    "IceFire", ["#000000" "#1F4E79" "#6BAED6" "#F7F7F7" "#F46D43" "#7F0000" "#000000"]; ...
    "CyclicMuted", ["#355C7D" "#6C5B7B" "#C06C84" "#F8B195" "#99B898" "#355C7D"]; ...
    "Azimuth", ["#08306B" "#1D91C0" "#7FCDBB" "#FFFFBF" "#FC8D59" "#B2182B" "#08306B"]; ...
    "Orientation", ["#2D004B" "#807DBA" "#41B6C4" "#ADDD8E" "#FEE391" "#E31A1C" "#2D004B"]});

presets = addPresetRows(presets, "Grayscale", "sequential", ...
    "internal", "none", { ...
    "BlackWhite", ["#000000" "#333333" "#777777" "#BBBBBB" "#FFFFFF"]; ...
    "SoftGray", ["#FAFAFA" "#E5E5E5" "#C7C7C7" "#969696" "#636363" "#252525"]});

presets = setBuiltInRecommendedUseNone(presets);
assert(numel(presets) <= 300, 'ColorKit preset library must stay at or below 300 entries.');
userPresets = loadUserPresetLibrary();
if ~isempty(userPresets)
    presets = [presets userPresets];
end
presets = applyUserMetadataOverrides(presets, loadUserMetadataOverrides());
assert(numel(presets) <= 300, 'ColorKit preset library must stay at or below 300 entries.');
end

function presets = setBuiltInRecommendedUseNone(presets)
for k = 1:numel(presets)
    presets(k).recommendedUse = "none";
end
end

function presets = addPresetRows(presets, category, typeValue, sourceStyle, defaultUse, rows, centerColor)
if nargin < 7
    centerColor = "";
end
for k = 1:size(rows, 1)
    presets = addPreset(presets, rows{k, 1}, category, typeValue, rows{k, 2}, ...
        defaultUse, "approximate", "approximate", centerColor, sourceStyle, "", []);
end
end

function userPresets = loadUserPresetLibrary()
userPresets = struct('name', {}, 'category', {}, 'type', {}, 'anchors', {}, ...
    'recommendedUse', {}, 'isColorblindFriendly', {}, 'isPrintFriendly', {}, ...
    'centerColor', {}, 'sourceStyle', {}, 'matlabName', {}, 'nativeN', {});
if exist('ColorKit_UserPresets', 'file') ~= 2
    return
end
try
    loaded = ColorKit_UserPresets();
catch
    return
end
if isempty(loaded)
    return
end
for k = 1:numel(loaded)
    userPresets(end + 1) = normalizePresetStruct(loaded(k)); %#ok<AGROW>
end
end

function overrides = loadUserMetadataOverrides()
overrides = struct('name', {}, 'recommendedUse', {});
if exist('ColorKit_UserMetadata', 'file') ~= 2
    return
end
try
    loaded = ColorKit_UserMetadata();
catch
    return
end
if isempty(loaded)
    return
end
for k = 1:numel(loaded)
    overrides(end + 1) = struct('name', string(loaded(k).name), ...
        'recommendedUse', string(loaded(k).recommendedUse)); %#ok<AGROW>
end
end

function presets = applyUserMetadataOverrides(presets, overrides)
if isempty(overrides)
    return
end
for k = 1:numel(overrides)
    mask = strcmpi(string({presets.name}), overrides(k).name);
    for idx = find(mask)
        presets(idx).recommendedUse = string(overrides(k).recommendedUse);
    end
end
end

function overrides = upsertRecommendedUseOverride(overrides, presetName, recommendedUse)
presetName = string(presetName);
recommendedUse = string(recommendedUse);
if isempty(overrides)
    overrides = struct('name', presetName, 'recommendedUse', recommendedUse);
    return
end
mask = strcmpi(string({overrides.name}), presetName);
if any(mask)
    overrides(find(mask, 1, 'first')).name = presetName;
    overrides(find(mask, 1, 'first')).recommendedUse = recommendedUse;
else
    overrides(end + 1) = struct('name', presetName, 'recommendedUse', recommendedUse);
end
end

function preset = normalizePresetStruct(inputPreset)
preset = struct('name', string(getStructField(inputPreset, 'name', "UserPreset")), ...
    'category', string(getStructField(inputPreset, 'category', "none")), ...
    'type', string(getStructField(inputPreset, 'type', "none")), ...
    'anchors', string(getStructField(inputPreset, 'anchors', strings(1, 0))), ...
    'recommendedUse', string(getStructField(inputPreset, 'recommendedUse', "none")), ...
    'isColorblindFriendly', string(getStructField(inputPreset, 'isColorblindFriendly', "none")), ...
    'isPrintFriendly', string(getStructField(inputPreset, 'isPrintFriendly', "none")), ...
    'centerColor', string(getStructField(inputPreset, 'centerColor', "none")), ...
    'sourceStyle', string(getStructField(inputPreset, 'sourceStyle', "none")), ...
    'matlabName', string(getStructField(inputPreset, 'matlabName', "")), ...
    'nativeN', getStructField(inputPreset, 'nativeN', []));
end

function value = getStructField(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function [row, info] = appendUserPreset(cmap, opts)
cmap = cleanCmap(cmap);
anchors = cmapToPresetHexAnchors(cmap, 64);
existingCatalog = presetCatalogTable(buildPresetLibrary());
nextID = height(existingCatalog) + 1;
name = strtrim(string(opts.PresetName));
if name == ""
    name = sprintf("UserPreset_%03d", nextID);
end
name = makeUniquePresetName(name, existingCatalog.Name);

paletteGroup = normalizePaletteGroup(opts.PresetCategory);
opts.PresetCategory = paletteGroup;
row = table(nextID, name, paletteGroup, string(opts.PresetType), ...
    numel(anchors), string(opts.RecommendedUse), string(opts.SourceStyle), ...
    'VariableNames', {'ID', 'Name', 'PaletteGroup', 'Type', 'Colors', ...
    'RecommendedUse', 'SourceStyle'});

targetFile = ensureUserPresetFile();
insertUserPresetRow(targetFile, name, anchors, opts);
info = struct('ID', nextID, 'Name', name, 'File', targetFile);
end

function name = makeUniquePresetName(name, existingNames)
baseName = regexprep(char(name), '[^a-zA-Z0-9_]', '_');
if isempty(baseName) || ~isletter(baseName(1))
    baseName = ['UserPreset_' baseName];
end
name = string(baseName);
candidate = name;
suffix = 2;
existingNames = string(existingNames);
normalizedExisting = strings(size(existingNames));
for k = 1:numel(existingNames)
    normalizedExisting(k) = normalizePresetName(existingNames(k));
end
while any(normalizePresetName(candidate) == normalizedExisting(:))
    candidate = sprintf("%s_%d", name, suffix);
    suffix = suffix + 1;
end
name = candidate;
end

function anchors = cmapToPresetHexAnchors(cmap, maxAnchors)
cmap = cleanCmap(cmap);
if size(cmap, 1) > maxAnchors
    idx = unique(round(linspace(1, size(cmap, 1), maxAnchors)));
    cmap = cmap(idx, :);
end
anchors = strings(1, size(cmap, 1));
for k = 1:size(cmap, 1)
    anchors(k) = string(rgb2hex(cmap(k, :)));
end
end

function targetFile = ensureUserPresetFile()
targetFile = fullfile(fileparts(mfilename('fullpath')), 'ColorKit_UserPresets.m');
if exist(targetFile, 'file') == 2
    return
end
fid = fopen(targetFile, 'w');
if fid < 0
    error('ColorKit:UserPresetFile', 'Could not create user preset file.');
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'function presets = ColorKit_UserPresets()\n');
fprintf(fid, '%% ColorKit_UserPresets  User-added presets generated by ColorKit.\n');
fprintf(fid, '%% Author: zhaoyh, 2026.\n');
fprintf(fid, '%% Email: zhao2025@mail.sustech.edu.cn\n');
fprintf(fid, '%% Edit metadata fields here if needed. Default values are \"none\".\n\n');
fprintf(fid, 'rows = cell(0, 9);\n');
fprintf(fid, '%% <ColorKit_USER_PRESETS_BEGIN>\n');
fprintf(fid, '%% <ColorKit_USER_PRESETS_END>\n\n');
fprintf(fid, 'presets = struct(''name'', {}, ''category'', {}, ''type'', {}, ''anchors'', {}, ...\n');
fprintf(fid, '    ''recommendedUse'', {}, ''isColorblindFriendly'', {}, ''isPrintFriendly'', {}, ...\n');
fprintf(fid, '    ''centerColor'', {}, ''sourceStyle'', {}, ''matlabName'', {}, ''nativeN'', {});\n');
fprintf(fid, 'for k = 1:size(rows, 1)\n');
fprintf(fid, '    presets(end + 1) = struct(''name'', string(rows{k, 1}), ... %%#ok<AGROW>\n');
fprintf(fid, '        ''category'', string(rows{k, 2}), ''type'', string(rows{k, 3}), ...\n');
fprintf(fid, '        ''anchors'', string(rows{k, 4}), ''recommendedUse'', string(rows{k, 5}), ...\n');
fprintf(fid, '        ''isColorblindFriendly'', string(rows{k, 6}), ...\n');
fprintf(fid, '        ''isPrintFriendly'', string(rows{k, 7}), ''centerColor'', string(rows{k, 8}), ...\n');
fprintf(fid, '        ''sourceStyle'', string(rows{k, 9}), ''matlabName'', \"\", ''nativeN'', []);\n');
fprintf(fid, 'end\n');
fprintf(fid, 'end\n');
clear cleanupObj
end

function targetFile = ensureUserMetadataFile()
targetFile = fullfile(fileparts(mfilename('fullpath')), 'ColorKit_UserMetadata.m');
if exist(targetFile, 'file') == 2
    return
end
writeUserMetadataOverrides(targetFile, struct('name', {}, 'recommendedUse', {}));
end

function writeUserMetadataOverrides(targetFile, overrides)
fid = fopen(targetFile, 'w');
if fid < 0
    error('ColorKit:UserMetadataFile', 'Could not write user metadata file.');
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'function metadata = ColorKit_UserMetadata()\n');
fprintf(fid, '%% ColorKit_UserMetadata  User-editable metadata overrides.\n');
fprintf(fid, '%% Author: zhaoyh, 2026.\n');
fprintf(fid, '%% Email: zhao2025@mail.sustech.edu.cn\n');
fprintf(fid, '%% Use ColorKit(''set-use'', nameOrID, recommendedUse) to update this file.\n\n');
fprintf(fid, 'rows = cell(0, 2);\n');
fprintf(fid, '%% <ColorKit_USER_METADATA_BEGIN>\n');
for k = 1:numel(overrides)
    fprintf(fid, 'rows(end + 1, :) = {"%s", "%s"};\n', ...
        escapeMatlabString(overrides(k).name), ...
        escapeMatlabString(overrides(k).recommendedUse));
end
fprintf(fid, '%% <ColorKit_USER_METADATA_END>\n\n');
fprintf(fid, 'metadata = struct(''name'', {}, ''recommendedUse'', {});\n');
fprintf(fid, 'if isempty(rows)\n');
fprintf(fid, '    return\n');
fprintf(fid, 'end\n');
fprintf(fid, 'metadata(1, size(rows, 1)) = struct(''name'', \"\", ''recommendedUse'', \"\");\n');
fprintf(fid, 'for k = 1:size(rows, 1)\n');
fprintf(fid, '    metadata(k) = struct(''name'', string(rows{k, 1}), ...\n');
fprintf(fid, '        ''recommendedUse'', string(rows{k, 2}));\n');
fprintf(fid, 'end\n');
fprintf(fid, 'end\n');
clear cleanupObj
end

function insertUserPresetRow(targetFile, name, anchors, opts)
text = string(fileread(targetFile));
marker = "% <ColorKit_USER_PRESETS_END>";
if ~contains(text, marker)
    error('ColorKit:UserPresetFile', 'User preset file is missing the insertion marker.');
end
anchorText = "[" + strjoin('"' + anchors + '"', " ") + "]";
rowText = sprintf('rows(end + 1, :) = {"%s", "%s", "%s", %s, "%s", "%s", "%s", "%s", "%s"};\n', ...
    escapeMatlabString(name), escapeMatlabString(opts.PresetCategory), ...
    escapeMatlabString(opts.PresetType), char(anchorText), ...
    escapeMatlabString(opts.RecommendedUse), escapeMatlabString(opts.IsColorblindFriendly), ...
    escapeMatlabString(opts.IsPrintFriendly), escapeMatlabString(opts.CenterColor), ...
    escapeMatlabString(opts.SourceStyle));
text = replace(text, marker, rowText + marker);
fid = fopen(targetFile, 'w');
if fid < 0
    error('ColorKit:UserPresetFile', 'Could not write user preset file.');
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(text));
clear cleanupObj
end

function text = escapeMatlabString(value)
text = char(string(value));
text = strrep(text, '"', '""');
end

function presets = addPreset(presets, name, category, typeValue, anchors, recommendedUse, ...
    colorblindFriendly, printFriendly, centerColor, sourceStyle, matlabName, nativeN)
if nargin < 11
    matlabName = "";
end
if nargin < 12
    nativeN = [];
end
entry = struct('name', string(name), 'category', string(category), ...
    'type', string(typeValue), 'anchors', string(anchors), ...
    'recommendedUse', string(recommendedUse), ...
    'isColorblindFriendly', string(colorblindFriendly), ...
    'isPrintFriendly', string(printFriendly), 'centerColor', string(centerColor), ...
    'sourceStyle', string(sourceStyle), 'matlabName', string(matlabName), ...
    'nativeN', nativeN);
presets(end + 1) = entry;
end

function [preset, id] = resolvePreset(presets, presetRef)
if isnumeric(presetRef) && isscalar(presetRef)
    id = round(double(presetRef));
    if id < 1 || id > numel(presets)
        error('ColorKit:UnknownPreset', 'Preset index must be between 1 and %d.', numel(presets));
    end
    preset = presets(id);
    return
end

target = normalizePresetName(string(presetRef));
names = arrayfun(@(p) normalizePresetName(p.name), presets);
id = find(names == target, 1);
if isempty(id)
    error('ColorKit:UnknownPreset', ...
        'Unknown preset "%s". Use ColorKit(''search'', keyword) or ColorKit(''catalog'').', string(presetRef));
end
preset = presets(id);
end

function key = normalizePresetName(value)
key = lower(regexprep(string(value), '[^a-zA-Z0-9]', ''));
end

function cmap = presetToColormap(preset, n)
if isempty(n)
    if strcmpi(preset.type, "qualitative")
        n = [];
    else
        n = 256;
    end
end

if strcmpi(preset.sourceStyle, "MATLAB")
    if isempty(n)
        n = preset.nativeN;
    end
    cmap = builtinPresetColormap(preset.matlabName, n);
    return
end

base = hexListToRgb(cellstr(preset.anchors));
if strcmpi(preset.type, "qualitative")
    if isempty(n)
        cmap = cleanCmap(base);
    else
        cmap = extendQualitativePalette(base, n);
    end
else
    n = normalizeLength(n, 2, 4096);
    method = 'pchip';
    if strcmpi(preset.type, "cyclic")
        method = 'linear';
    end
    cmap = resamplePalette(base, n, method);
end
end

function cmap = builtinPresetColormap(name, n)
name = char(lower(string(name)));
n = normalizeLength(n, 1, 4096);
if strcmp(name, 'white')
    cmap = ones(n, 3);
    return
end
try
    cmap = feval(name, n);
catch
    switch name
        case 'turbo'
            cmap = resamplePalette(hexListToRgb({'#30123B', '#4664D7', '#36A9E1', '#31B57B', '#F8E620', '#F46D43', '#A50026'}), n, 'pchip');
        otherwise
            cmap = parula(n);
    end
end
cmap = cleanCmap(cmap(:, 1:3));
end

function cmap = extendQualitativePalette(base, n)
n = normalizeLength(n, 1, 4096);
base = cleanCmap(base);
if n <= size(base, 1)
    cmap = base(1:n, :);
    return
end
hsvBase = rgb2hsv(base);
cmap = zeros(n, 3);
for k = 1:n
    src = mod(k - 1, size(base, 1)) + 1;
    cycle = floor((k - 1) / size(base, 1));
    hsvValue = hsvBase(src, :);
    hsvValue(1) = mod(hsvValue(1) + 0.17 * cycle, 1);
    hsvValue(2) = min(0.92, max(0.25, hsvValue(2) * (0.92 - 0.05 * mod(cycle, 3))));
    hsvValue(3) = min(0.98, max(0.28, hsvValue(3) * (0.96 + 0.03 * mod(cycle, 2))));
    cmap(k, :) = hsv2rgb(hsvValue);
end
cmap = cleanCmap(cmap);
end

function groups = standardPaletteGroups()
% Palette group meanings:
% Built-in: MATLAB built-in and basic commonly used colormaps.
% Sequential: one-directional continuous variables.
% Diverging: centered or positive-negative data.
% Categorical: categorical data, lines, stations, events, sample groups.
% Cyclic: phase, azimuth, orientation, and periodic variables.
% Grayscale: grayscale or near-monochrome palettes for B/W printing.
% Custom: default group for user-defined palettes without a group.
groups = ["All"; "Built-in"; "Sequential"; "Diverging"; ...
    "Categorical"; "Cyclic"; "Grayscale"; "Custom"];
end

function group = paletteGroupForPreset(preset)
name = string(preset.name);
legacyCategory = string(preset.category);
sourceStyle = string(preset.sourceStyle);

if any(strcmpi(name, ["gray", "bone", "white"]))
    group = "Grayscale";
elseif strcmpi(legacyCategory, "Zhao") || ...
        (any(strcmpi(legacyCategory, ["none", "user", "custom"])) && strcmpi(sourceStyle, "none"))
    group = "Custom";
else
    group = normalizePaletteGroup(legacyCategory);
end
end

function group = normalizePaletteGroup(value)
value = strtrim(string(value));
if value == "" || strcmpi(value, "none") || strcmpi(value, "user") || ...
        strcmpi(value, "custom") || strcmpi(value, "zhao")
    group = "Custom";
    return
end
groups = standardPaletteGroups();
groupsNoAll = groups(groups ~= "All");
idx = find(strcmpi(groupsNoAll, value), 1);
if ~isempty(idx)
    group = groupsNoAll(idx);
else
    group = value;
end
end

function description = paletteGroupDescription(group)
switch char(group)
    case 'Built-in'
        description = "MATLAB built-in and basic commonly used colormaps.";
    case 'Sequential'
        description = "One-directional continuous variables.";
    case 'Diverging'
        description = "Centered or positive-negative variables.";
    case 'Categorical'
        description = "Categorical data, multiple lines, stations, events, or sample groups.";
    case 'Cyclic'
        description = "Phase, azimuth, orientation, and periodic variables.";
    case 'Grayscale'
        description = "Grayscale or near-monochrome palettes for black-and-white printing.";
    case 'Custom'
        description = "Default group for user-defined palettes without a custom group.";
    otherwise
        description = "User-defined palette group.";
end
end

function tableOut = presetCatalogTable(presets)
n = numel(presets);
id = (1:n)';
name = strings(n, 1);
paletteGroup = strings(n, 1);
type = strings(n, 1);
colors = zeros(n, 1);
recommendedUse = strings(n, 1);
sourceStyle = strings(n, 1);
for k = 1:n
    name(k) = presets(k).name;
    paletteGroup(k) = paletteGroupForPreset(presets(k));
    type(k) = presets(k).type;
    if strcmpi(presets(k).sourceStyle, "MATLAB")
        colors(k) = presets(k).nativeN;
    else
        colors(k) = numel(presets(k).anchors);
    end
    recommendedUse(k) = presets(k).recommendedUse;
    sourceStyle(k) = presets(k).sourceStyle;
end
tableOut = table(id, name, paletteGroup, type, colors, recommendedUse, ...
    sourceStyle, ...
    'VariableNames', {'ID', 'Name', 'PaletteGroup', 'Type', 'Colors', ...
    'RecommendedUse', 'SourceStyle'});
end

function tableOut = presetSummaryTable(presets)
catalog = presetCatalogTable(presets);
paletteGroup = standardPaletteGroups();
paletteGroup = paletteGroup(ismember(paletteGroup, catalog.PaletteGroup));
count = zeros(numel(paletteGroup), 1);
types = strings(numel(paletteGroup), 1);
for k = 1:numel(paletteGroup)
    mask = catalog.PaletteGroup == paletteGroup(k);
    count(k) = nnz(mask);
    types(k) = strjoin(unique(catalog.Type(mask), 'stable'), ", ");
end
description = strings(numel(paletteGroup), 1);
for k = 1:numel(paletteGroup)
    description(k) = paletteGroupDescription(paletteGroup(k));
end
tableOut = table(paletteGroup, count, types, description, ...
    'VariableNames', {'PaletteGroup', 'Count', 'Types', 'Description'});
end

function categories = presetCategories()
categories = standardPaletteGroups();
end

function matches = searchPresetCatalog(keyword)
library = buildPresetLibrary();
catalog = presetCatalogTable(buildPresetLibrary());
keyword = lower(strtrim(string(keyword)));
if keyword == "" || keyword == "all"
    matches = catalog;
    return
end
legacyCategory = string({library.category}).';
haystack = lower(catalog.Name + " " + catalog.PaletteGroup + " " + legacyCategory + ...
    " " + catalog.Type + " " + catalog.RecommendedUse + " " + catalog.SourceStyle);
matches = catalog(contains(haystack, keyword), :);
end

function presets = filterPresetLibrary(filterText)
library = buildPresetLibrary();
catalog = presetCatalogTable(library);
filterText = strtrim(string(filterText));
if filterText == "" || strcmpi(filterText, "all") || strcmpi(filterText, "palette")
    presets = library;
    return
end

groupMask = strcmpi(catalog.PaletteGroup, filterText);
if any(groupMask)
    presets = library(groupMask);
    return
end

matches = searchPresetCatalog(filterText);
presets = library(matches.ID);
end

function [fig, info] = presetCardsFigure(args)
filterText = "all";
if ~isempty(args) && (ischar(args{1}) || isstring(args{1})) && ~isColorOptionKey(args{1})
    filterText = string(args{1});
    args = args(2:end);
end

presets = filterPresetLibrary(filterText);
if isempty(presets)
    error('ColorKit:NoPresetMatches', 'No palettes match "%s".', filterText);
end

[startIndex, args] = popColorLeadingNumber(args, 1);
[endIndex, args] = popColorLeadingNumber(args, min(numel(presets), startIndex + 35));
opts = parseColorUserOptions(args);
startIndex = max(1, min(numel(presets), round(startIndex)));
endIndex = max(startIndex, min(numel(presets), round(endIndex)));
presets = presets(startIndex:endIndex);

visibleValue = 'on';
if ~opts.Visible
    visibleValue = 'off';
end

fig = figure('Name', sprintf('ColorKit cards: %s', filterText), ...
    'NumberTitle', 'off', 'Color', 'white', 'Visible', visibleValue, ...
    'Position', [80 80 1480 880]);
plotPresetCardsFromLibrary(fig, presets, opts.NColors, opts.Columns, ...
    sprintf('ColorKit cards: %s (%d-%d)', filterText, startIndex, endIndex));
if ~isempty(opts.SaveFile)
    exportgraphics(fig, opts.SaveFile, 'Resolution', 300);
end

info = struct('Filter', filterText, 'StartIndex', startIndex, 'EndIndex', endIndex, ...
    'Count', numel(presets), 'NColors', opts.NColors, 'SaveFile', opts.SaveFile);
end

function plotPresetCardsFromLibrary(fig, presets, mapN, columns, titleText)
columns = max(1, min(8, round(columns)));
rows = ceil(numel(presets) / columns);
layout = tiledlayout(fig, rows, columns, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, titleText, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 16);
catalogNames = string({buildPresetLibrary().name});
for k = 1:numel(presets)
    ax = nexttile(layout);
    cmap = presetToColormap(presets(k), mapN);
    strip = repmat(1:size(cmap, 1), 12, 1);
    imagesc(ax, strip);
    colormap(ax, cmap);
    set(ax, 'CLim', [1 size(cmap, 1)], 'XTick', [], 'YTick', []);
    id = find(strcmp(catalogNames, string(presets(k).name)), 1, 'first');
    if isempty(id)
        id = NaN;
    end
    title(ax, sprintf('%03d | %s (%d)', id, char(presets(k).name), size(cmap, 1)), ...
        'FontName', 'Arial', 'FontWeight', 'normal', 'FontSize', 7.5, ...
        'Interpreter', 'none');
    box(ax, 'on');
end
end

function points = normalizeColorPoints(points)
if isempty(points)
    return
end
points = double(points);
if size(points, 2) ~= 2 && size(points, 1) == 2
    points = points';
end
if size(points, 2) ~= 2
    error('ColorKit:InvalidPoints', 'Points must be an N-by-2 array: [x y].');
end
points = points(all(isfinite(points), 2), :);
end

function value = normalizeColorCount(value, minValue, maxValue)
if isempty(value) || ~isscalar(value) || ~isfinite(value)
    value = minValue;
end
value = max(minValue, min(maxValue, round(double(value))));
end

function tf = logicalColorScalar(value)
if islogical(value)
    tf = any(value(:));
elseif isnumeric(value)
    tf = any(value(:) ~= 0);
elseif ischar(value) || isstring(value)
    text = strtrim(char(value));
    tf = any(strcmpi(text, {'1', 'true', 'yes', 'on'}));
else
    tf = false;
end
end

function showColorHelp()
fprintf('ColorKit colormap toolkit by zhaoyh <zhao2025@mail.sustech.edu.cn>\n');
fprintf('  C = ColorKit(''palette'', ''Blue'', ''nColors'', N, ''preview'', true)\n');
fprintf('  C = ColorKit(''ramp'', ''BlueWhiteRed'', ''nColors'', N, ''preview'', true)\n');
fprintf('  C = ColorKit(''pick'', ''preview'', true)\n');
fprintf('  C = ColorKit(''imagebar'', img, ''samples'', sampleCount, ''nColors'', N)\n');
fprintf('  C = ColorKit(''theme-grid'', count, ''preview'', true)\n');
fprintf('  C = ColorKit(''theme-cluster'', count, ''preview'', true)\n');
fprintf('  row = ColorKit(''set-use'', ''Blue'', ''amplitude map'')\n');
fprintf('  ColorKit(''cards'', ''Blue'', 1, 24, ''nColors'', 256)\n');
fprintf('  matches = ColorKit(''search'', ''blue'')\n');
fprintf('  catalog = ColorKit(''catalog'')\n');
fprintf('  summary = ColorKit(''about'')\n');
end

function varargout = colorEngine(mode, varargin)
% colorEngine - Internal implementation for ColorKit.
%
% Colors are returned as N-by-3 RGB values in the [0, 1] range.

if nargin == 0
    showHelp();
    return
end

mode = lower(strtrim(char(mode)));
if strcmp(mode, '__selftest__')
    runSelfTests();
    if nargout > 0
        varargout{1} = true;
    end
    return
end

switch mode
    case {'palette', 'preset'}
        [cmap, info] = modePalette(varargin);
    case 'gradient'
        [cmap, info] = modeGradient(varargin);
    case 'copy'
        [cmap, info] = modeCopy(varargin);
    case 'copymap'
        [cmap, info] = modeCopyMap(varargin);
    case {'img2palette1', 'imagepalette1'}
        [cmap, info] = modeImagePalette(varargin, 'grid');
    case {'img2palette2', 'imagepalette2'}
        [cmap, info] = modeImagePalette(varargin, 'kmeans');
    case {'view', 'show'}
        [cmap, info] = modeView(varargin);
    case {'list', 'catalog'}
        [cmap, info] = modeList(varargin);
    case {'info', 'summary'}
        [cmap, info] = modeInfo(varargin);
    case {'cheatsheet', 'cards'}
        [cmap, info] = modeCheatsheet(varargin);
    otherwise
        error('colorEngine:UnknownMode', 'Unknown mode "%s". Run ColorKit with no inputs for help.', mode);
end

if nargout == 0
    if isempty(cmap) && isstruct(info) && isfield(info, 'Message')
        fprintf('%s\n', info.Message);
    elseif istable(cmap)
        disp(cmap);
    end
else
    varargout{1} = cmap;
    if nargout > 1
        varargout{2} = info;
    end
end
end

function runSelfTests()
fprintf('Running colorEngine self-tests...\n');

c1 = colorEngine('palette', 1, 'seka', 0);
assert(size(c1, 2) == 3 && size(c1, 1) >= 2, 'Color palette must be N-by-3.');
assert(all(c1(:) >= 0 & c1(:) <= 1), 'Color palette values must be in [0, 1].');

c2 = colorEngine('palette', 4, 'map', 256, 'seka', 0);
assert(isequal(size(c2), [256 3]), 'Color map mode must return requested length.');

g1 = colorEngine('gradient', 5, 'map', 10, 'seka', 0);
assert(isequal(size(g1), [10 3]), 'Gradient mode must return requested length.');
assert(all(isfinite(g1(:))), 'Gradient colors must be finite.');
gAlias = colorEngine('gradient', 1, 'map', 256, 'seka', 0);
pAlias = colorEngine('palette', 1, 'map', 256, 'seka', 0);
assert(max(abs(gAlias(:) - pAlias(:))) < 1e-12, ...
    'Gradient mode must be an alias for palette(id, map, N).');

img = zeros(32, 48, 3);
img(:, 1:16, 1) = 1;
img(:, 17:32, 2) = 1;
img(:, 33:48, 3) = 1;
picked = colorEngine('copy', img, 'points', [8 16; 24 16; 40 16], 'seka', 0);
assert(isequal(size(picked), [3 3]), 'Copy mode must sample requested points.');
assert(norm(picked(1, :) - [1 0 0]) < 1e-12, 'Copy mode sampled the wrong first color.');

barImg = repmat(reshape(linspace(0, 1, 50), 1, [], 1), 10, 1, 3);
mapC = colorEngine('copymap', 5, barImg, 'endpoints', [1 5; 50 5], 'map', 11, 'seka', 0);
assert(isequal(size(mapC), [11 3]), 'Copymap mode must support map densification.');
assert(mapC(1, 1) < 0.05 && mapC(end, 1) > 0.95, 'Copymap endpoints were not sampled correctly.');

p1 = colorEngine('img2palette1', 3, img, 'seka', 0);
p2 = colorEngine('img2palette2', 3, img, 'seka', 0);
assert(isequal(size(p1), [3 3]), 'Grid palette extraction must return N colors.');
assert(isequal(size(p2), [3 3]), 'K-means palette extraction must return N colors.');

catalog = colorEngine('list');
assert(istable(catalog) && height(catalog) <= 300, 'List mode must return the curated catalog.');

summary = colorEngine('info');
assert(istable(summary) && height(summary) >= 4, 'Info mode must return a summary table.');

oldVisible = get(groot, 'defaultFigureVisible');
set(groot, 'defaultFigureVisible', 'off');
cleanupObj = onCleanup(@() set(groot, 'defaultFigureVisible', oldVisible));
fig = colorEngine('cheatsheet', 'palette', 1, 4, 'visible', 0);
assert(isvalid(fig), 'Cheatsheet mode must return a valid figure.');
delete(fig);
clear cleanupObj

fprintf('colorEngine self-tests passed.\n');
end

function [cmap, info] = modePalette(args)
[id, args] = popLeadingNumber(args, 1);
opts = parseOptions(args);

cmap = makeColorPalette(id);
originalN = size(cmap, 1);
if ~isempty(opts.MapN)
    cmap = resamplePalette(cmap, opts.MapN, 'pchip');
end

info = struct('Mode', 'palette', 'ID', id, 'OriginalLength', originalN, ...
    'Length', size(cmap, 1), 'LibrarySize', numel(buildPresetLibrary()));
if opts.Seka
    showPalette(cmap, sprintf('Color palette %d (%d colors)', id, size(cmap, 1)), true);
end
end

function [cmap, info] = modeGradient(args)
[id, args] = popLeadingNumber(args, 1);
opts = parseOptions(args);
targetN = opts.MapN;
if isempty(targetN)
    targetN = 256;
end

cmap = resamplePalette(makeColorPalette(id), targetN, 'pchip');
info = struct('Mode', 'gradient', 'ID', id, 'Length', size(cmap, 1));
if opts.Seka
    showPalette(cmap, sprintf('Gradient palette %d (%d colors)', id, size(cmap, 1)), false);
end
end

function [cmap, info] = modeCopy(args)
[imageInput, args] = popLeadingImage(args);
opts = parseOptions(args);
if isempty(opts.Image)
    opts.Image = imageInput;
end

[img, source, canceled] = resolveImage(opts.Image);
if canceled
    cmap = [];
    info = struct('Mode', 'copy', 'Canceled', true, 'Message', 'Image selection canceled.');
    return
end

points = opts.Points;
if isempty(points)
    points = interactivePickPoints(img, 'Select one or more colors, then press Enter', inf);
end

if isempty(points)
    cmap = [];
    info = struct('Mode', 'copy', 'Canceled', true, 'Source', source, 'Message', 'No points selected.');
    return
end

cmap = sampleImagePoints(img, points);
if ~isempty(opts.MapN) && size(cmap, 1) >= 2
    cmap = resamplePalette(cmap, opts.MapN, 'pchip');
end

info = struct('Mode', 'copy', 'Source', source, 'Points', points, 'Length', size(cmap, 1));
if opts.Seka
    showPalette(cmap, sprintf('Picked colors (%d)', size(cmap, 1)), true);
end
end

function [cmap, info] = modeCopyMap(args)
[sampleN, args] = popLeadingNumber(args, 10);
[imageInput, args] = popLeadingImage(args);
opts = parseOptions(args);
if isempty(opts.Image)
    opts.Image = imageInput;
end

sampleN = normalizeLength(sampleN, 2, 4096);
[img, source, canceled] = resolveImage(opts.Image);
if canceled
    cmap = [];
    info = struct('Mode', 'copymap', 'Canceled', true, 'Message', 'Image selection canceled.');
    return
end

endpoints = opts.Endpoints;
if isempty(endpoints)
    endpoints = interactivePickPoints(img, 'Select the first and last colorbar points, then press Enter', 2);
end
if size(endpoints, 1) < 2
    cmap = [];
    info = struct('Mode', 'copymap', 'Canceled', true, 'Source', source, ...
        'Message', 'At least two colorbar points are required.');
    return
end

sampled = sampleColorbarLine(img, endpoints(1:2, :), sampleN);
cmap = sampled;
if ~isempty(opts.MapN)
    cmap = resamplePalette(sampled, opts.MapN, 'pchip');
end

info = struct('Mode', 'copymap', 'Source', source, 'Endpoints', endpoints(1:2, :), ...
    'SampleLength', size(sampled, 1), 'Length', size(cmap, 1));
if opts.Seka
    showPalette(cmap, sprintf('Colorbar map (%d colors)', size(cmap, 1)), false);
end
end

function [cmap, info] = modeImagePalette(args, method)
[n, args] = popLeadingNumber(args, 8);
[imageInput, args] = popLeadingImage(args);
opts = parseOptions(args);
if isempty(opts.Image)
    opts.Image = imageInput;
end

n = normalizeLength(n, 2, 64);
[img, source, canceled] = resolveImage(opts.Image);
if canceled
    cmap = [];
    info = struct('Mode', ['img2palette-' method], 'Canceled', true, 'Message', 'Image selection canceled.');
    return
end

switch method
    case 'grid'
        cmap = extractThemeGrid(img, n);
    otherwise
        cmap = extractThemeKmeans(img, n);
end

info = struct('Mode', ['img2palette-' method], 'Source', source, 'Length', size(cmap, 1));
if opts.Seka
    showImageWithPalette(img, cmap, sprintf('Image theme colors: %s', method));
end
end

function [catalog, info] = modeList(args)
opts = parseOptions(args);
catalog = presetCatalogTable(buildPresetLibrary());
info = struct('Mode', 'list', 'LibrarySize', height(catalog));
if opts.Seka
    modeView({'palette', 1, 24});
end
end

function [summary, info] = modeInfo(args)
parseOptions(args);
summary = presetSummaryTable(buildPresetLibrary());
info = struct('Mode', 'info', 'LibrarySize', sum(summary.Count));
if nargout == 0
    disp(summary);
end
end

function [fig, info] = modeCheatsheet(args)
[family, args] = popLeadingFamily(args, 'palette');
[startID, args] = popLeadingNumber(args, 1);
[endID, args] = popLeadingNumber(args, startID + 99);
opts = parseOptions(args);
extra = parseCheatsheetOptions(args);

librarySize = numel(buildPresetLibrary());
startID = max(1, min(librarySize, round(startID)));
endID = max(startID, min(librarySize, round(endID)));
ids = startID:endID;
mapN = opts.MapN;
if strcmpi(family, 'gradient') && isempty(mapN)
    mapN = 256;
end
if extra.Continuous && isempty(mapN)
    mapN = 256;
end

if extra.Visible
    visibleValue = 'on';
else
    visibleValue = 'off';
end

fig = figure('Name', sprintf('ColorKit %s cards %d-%d', family, startID, endID), ...
    'NumberTitle', 'off', 'Color', 'white', 'Visible', visibleValue, ...
    'Position', [80 80 1420 880]);

titleText = sprintf('ColorKit %s cards: %d-%d', family, startID, endID);
plotPaletteCards(fig, family, ids, mapN, extra.Columns, titleText);

if ~isempty(extra.SaveFile)
    exportgraphics(fig, extra.SaveFile, 'Resolution', 300);
end

info = struct('Mode', 'cheatsheet', 'Family', family, 'StartID', startID, ...
    'EndID', endID, 'Count', numel(ids), 'MapN', mapN, 'SaveFile', extra.SaveFile);
end

function [cmap, info] = modeView(args)
cmap = [];
if isempty(args)
    family = 'palette';
else
    family = lower(char(args{1}));
    args = args(2:end);
end
if ~strcmp(family, 'palette')
    error('colorEngine:UnsupportedView', 'Only the palette card view is supported.');
end

[startID, args] = popLeadingNumber(args, 1);
[endID, args] = popLeadingNumber(args, startID + 23);
opts = parseOptions(args);
startID = max(1, round(startID));
endID = min(numel(buildPresetLibrary()), max(startID, round(endID)));

showPaletteCatalog(startID, endID);
info = struct('Mode', 'view', 'Family', family, 'StartID', startID, 'EndID', endID);
if opts.Seka
    fprintf('Displayed ColorKit palettes %d to %d.\n', startID, endID);
end
end

function [family, args] = popLeadingFamily(args, defaultFamily)
family = defaultFamily;
if isempty(args) || ~(ischar(args{1}) || isstring(args{1}))
    return
end

candidate = lower(strtrim(char(args{1})));
if any(strcmp(candidate, {'palette', 'preset', 'gradient'}))
    if strcmp(candidate, 'palette') || strcmp(candidate, 'preset')
        family = 'palette';
    else
        family = candidate;
    end
    args = args(2:end);
end
end

function extra = parseCheatsheetOptions(args)
extra = struct('Columns', 4, 'SaveFile', '', 'Visible', true, 'Continuous', false);

i = 1;
while i <= numel(args)
    key = args{i};
    if ischar(key) || isstring(key)
        keyText = lower(strtrim(char(key)));
        if any(strcmp(keyText, {'cols', 'columns'}))
            [value, i] = readOptionValue(args, i, 4);
            extra.Columns = max(1, min(8, round(double(value))));
        elseif any(strcmp(keyText, {'save', 'filename', 'file', 'export'}))
            [value, i] = readOptionValue(args, i, '');
            extra.SaveFile = char(string(value));
        elseif strcmp(keyText, 'visible')
            [value, i] = readOptionValue(args, i, true);
            extra.Visible = logicalScalar(value);
        elseif any(strcmp(keyText, {'continuous', 'dense'}))
            [value, i] = readOptionValue(args, i, true);
            extra.Continuous = logicalScalar(value);
        else
            i = i + 1;
        end
    else
        i = i + 1;
    end
end
end

function plotPaletteCards(fig, family, ids, mapN, columns, titleText)
rows = ceil(numel(ids) / columns);
layout = tiledlayout(fig, rows, columns, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, titleText, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 16);

for k = 1:numel(ids)
    ax = nexttile(layout);
    id = ids(k);
    cmap = makeColorPalette(id);
    if strcmpi(family, 'gradient') && isempty(mapN)
        mapN = 256;
    end
    if ~isempty(mapN)
        cmap = resamplePalette(cmap, mapN, 'pchip');
    end

    strip = repmat(1:size(cmap, 1), 12, 1);
    imagesc(ax, strip);
    colormap(ax, cmap);
    set(ax, 'CLim', [1 size(cmap, 1)], 'XTick', [], 'YTick', []);
    title(ax, sprintf('%d (%d)', id, size(cmap, 1)), ...
        'FontName', 'Arial', 'FontWeight', 'normal', 'FontSize', 9);
    box(ax, 'on');
end
end

function opts = parseOptions(args)
opts = struct('Seka', false, 'MapN', [], 'Image', [], 'Points', [], ...
    'Endpoints', [], 'Title', '');

i = 1;
while i <= numel(args)
    key = args{i};
    if ischar(key) || isstring(key)
        keyText = lower(strtrim(char(key)));
        if any(strcmp(keyText, {'seka', 'show'}))
            [opts.Seka, i] = readOptionValue(args, i, true);
        elseif any(strcmp(keyText, {'map', 'n', 'length'}))
            [opts.MapN, i] = readOptionValue(args, i, 256);
            opts.MapN = normalizeLength(opts.MapN, 2, 4096);
        elseif any(strcmp(keyText, {'image', 'img', 'file'}))
            [opts.Image, i] = readOptionValue(args, i, []);
        elseif any(strcmp(keyText, {'points', 'point', 'xy'}))
            [opts.Points, i] = readOptionValue(args, i, []);
        elseif any(strcmp(keyText, {'endpoints', 'endpoint', 'line'}))
            [opts.Endpoints, i] = readOptionValue(args, i, []);
        elseif strcmp(keyText, 'title')
            [opts.Title, i] = readOptionValue(args, i, '');
        else
            i = i + 1;
        end
    else
        i = i + 1;
    end
end

opts.Seka = logicalScalar(opts.Seka);
opts.Points = normalizePointArray(opts.Points);
opts.Endpoints = normalizePointArray(opts.Endpoints);
end

function [value, nextIndex] = readOptionValue(args, keyIndex, defaultValue)
if keyIndex + 1 <= numel(args)
    value = args{keyIndex + 1};
    nextIndex = keyIndex + 2;
else
    value = defaultValue;
    nextIndex = keyIndex + 1;
end
end

function [value, args] = popLeadingNumber(args, defaultValue)
value = defaultValue;
if ~isempty(args) && isnumeric(args{1}) && isscalar(args{1})
    value = args{1};
    args = args(2:end);
elseif ~isempty(args) && (ischar(args{1}) || isstring(args{1}))
    candidate = str2double(args{1});
    if isfinite(candidate)
        value = candidate;
        args = args(2:end);
    end
end
end

function [imageInput, args] = popLeadingImage(args)
imageInput = [];
if isempty(args)
    return
end
candidate = args{1};
if isnumeric(candidate) && ndims(candidate) >= 2 && ~isscalar(candidate)
    imageInput = candidate;
    args = args(2:end);
elseif ischar(candidate) || isstring(candidate)
    text = char(candidate);
    if exist(text, 'file') == 2
        imageInput = text;
        args = args(2:end);
    end
end
end

function tf = logicalScalar(value)
if islogical(value)
    tf = any(value(:));
elseif isnumeric(value)
    tf = any(value(:) ~= 0);
elseif ischar(value) || isstring(value)
    text = strtrim(char(value));
    tf = any(strcmpi(text, {'1', 'true', 'yes', 'on'}));
else
    tf = false;
end
end

function points = normalizePointArray(points)
if isempty(points)
    points = [];
    return
end
points = double(points);
if size(points, 2) ~= 2 && size(points, 1) == 2
    points = points';
end
if size(points, 2) ~= 2
    error('colorEngine:InvalidPoints', 'Points must be an N-by-2 array: [x y].');
end
points = points(all(isfinite(points), 2), :);
end

function [type, family, description, colors, goodFor] = describePaletteID(id)
catalog = presetCatalogTable(buildPresetLibrary());
id = max(1, min(height(catalog), round(double(id))));
type = catalog.Type(id);
family = catalog.PaletteGroup(id);
description = catalog.SourceStyle(id);
colors = catalog.Colors(id);
goodFor = catalog.RecommendedUse(id);
end

function cmap = makeColorPalette(id)
presets = buildPresetLibrary();
id = max(1, min(numel(presets), round(double(id))));
cmap = presetToColormap(presets(id), []);
end

function cmap = makeGradientPalette(id, n)
presets = buildPresetLibrary();
id = max(1, min(numel(presets), round(double(id))));
cmap = presetToColormap(presets(id), n);
end

function families = basePaletteFamilies()
families = { ...
    hexListToRgb({'#2A363B', '#019875', '#99B898', '#FECEA8', '#FF847C', '#E84A5F', '#C0392B'}), ...
    hexListToRgb({'#0B1F33', '#276E90', '#6AA6B8', '#F4E7C5', '#E8954A', '#A6433B'}), ...
    hexListToRgb({'#3B4A6B', '#6C8EBF', '#D8E2F0', '#F2E6C9', '#D7905B', '#8C3B3B'}), ...
    hexListToRgb({'#313695', '#4575B4', '#74ADD1', '#ABD9E9', '#FFFFBF', '#FDAE61', '#F46D43', '#D73027', '#A50026'}), ...
    hexListToRgb({'#2166AC', '#4393C3', '#92C5DE', '#F7F7F7', '#F4A582', '#D6604D', '#B2182B'}), ...
    hexListToRgb({'#40004B', '#762A83', '#9970AB', '#C2A5CF', '#F7F7F7', '#A6DBA0', '#5AAE61', '#1B7837', '#00441B'}), ...
    hexListToRgb({'#440154', '#414487', '#2A788E', '#22A884', '#7AD151', '#FDE725'}), ...
    hexListToRgb({'#0D0887', '#5B02A3', '#9A179B', '#CB4679', '#ED7953', '#FDB42F', '#F0F921'}), ...
    hexListToRgb({'#000004', '#1B0C41', '#4A0C6B', '#781C6D', '#BB3754', '#ED6925', '#FCFFA4'}), ...
    hexListToRgb({'#00224E', '#123570', '#3B496C', '#575D6D', '#707173', '#8A8678', '#A59C74', '#C3B369', '#E1CC55', '#FDE737'}), ...
    hexListToRgb({'#0B132B', '#1C2541', '#3A506B', '#5BC0BE', '#F4F1DE', '#E07A5F', '#B56576'}), ...
    hexListToRgb({'#264653', '#2A9D8F', '#E9C46A', '#F4A261', '#E76F51'}), ...
    hexListToRgb({'#355070', '#6D597A', '#B56576', '#E56B6F', '#EAAC8B'}), ...
    hexListToRgb({'#003F5C', '#58508D', '#BC5090', '#FF6361', '#FFA600'}), ...
    hexListToRgb({'#012A4A', '#2A6F97', '#61A5C2', '#A9D6E5', '#F6F2D4', '#F4A261', '#BC4749'}), ...
    hexListToRgb({'#081C15', '#1B4332', '#40916C', '#95D5B2', '#D8F3DC'}), ...
    hexListToRgb({'#3D348B', '#7678ED', '#F7B801', '#F18701', '#F35B04'}), ...
    hexListToRgb({'#14213D', '#2D6A4F', '#B7E4C7', '#FFF8D6', '#F77F00', '#D62828'}), ...
    hexListToRgb({'#5F0F40', '#9A031E', '#FB8B24', '#E36414', '#0F4C5C'}), ...
    hexListToRgb({'#073B4C', '#118AB2', '#06D6A0', '#FFD166', '#EF476F'}), ...
    hexListToRgb({'#4B4E6D', '#84DCC6', '#A5FFD6', '#FFA69E', '#FF686B'}), ...
    hexListToRgb({'#1B263B', '#415A77', '#778DA9', '#E0E1DD', '#B08968', '#7F5539'}), ...
    hexListToRgb({'#22223B', '#4A4E69', '#9A8C98', '#C9ADA7', '#F2E9E4'}), ...
    hexListToRgb({'#0B3954', '#087E8B', '#BFD7EA', '#FF5A5F', '#C81D25'}) ...
    };
end

function names = baseFamilyNames()
names = [ ...
    "muted teal-coral"; ...
    "deep blue-orange"; ...
    "low-saturation blue tan"; ...
    "research red-blue diverging"; ...
    "red-blue balanced"; ...
    "purple-green diverging"; ...
    "viridis-like"; ...
    "plasma-like"; ...
    "inferno-like"; ...
    "cividis-like"; ...
    "navy-teal-coral"; ...
    "earth science teal-sand"; ...
    "muted mauve"; ...
    "blue-magenta-orange"; ...
    "hydrology blue-orange"; ...
    "forest sequential"; ...
    "purple-yellow-orange"; ...
    "muted green-red"; ...
    "burgundy-orange-teal"; ...
    "cyan-yellow-rose"; ...
    "pastel teal-coral"; ...
    "slate-bone-brown"; ...
    "neutral mauve"; ...
    "marine red accent"];
end

function cmap = generatedQualitative(base, n, variation)
n = normalizeLength(n, 2, 512);
base = varyPalette(base, variation);
if n <= size(base, 1)
    cmap = base(1:n, :);
    return
end

hsvBase = rgb2hsv(base);
result = zeros(n, 3);
for k = 1:n
    src = mod(k - 1, size(hsvBase, 1)) + 1;
    cycle = floor((k - 1) / size(hsvBase, 1));
    hue = mod(hsvBase(src, 1) + 0.135 * cycle + 0.017 * variation, 1);
    sat = min(0.92, max(0.25, hsvBase(src, 2) * (0.92 - 0.06 * mod(cycle, 4))));
    val = min(0.98, max(0.25, hsvBase(src, 3) * (0.95 + 0.04 * mod(cycle, 3))));
    result(k, :) = hsv2rgb([hue sat val]);
end
cmap = cleanCmap(result);
end

function cmap = varyPalette(cmap, variation)
if variation == 0
    cmap = cleanCmap(cmap);
    return
end

hsvMap = rgb2hsv(cleanCmap(cmap));
hueShift = mod(variation * 0.037, 1);
satScale = 0.78 + 0.06 * mod(variation, 6);
valScale = 0.90 + 0.035 * mod(floor(variation / 2), 5);
hsvMap(:, 1) = mod(hsvMap(:, 1) + hueShift, 1);
hsvMap(:, 2) = clip01(hsvMap(:, 2) .* satScale);
hsvMap(:, 3) = clip01(hsvMap(:, 3) .* valScale);
cmap = hsv2rgb(hsvMap);
if mod(variation, 7) == 3
    cmap = flipud(cmap);
end
cmap = cleanCmap(cmap);
end

function cmap = resamplePalette(cmap, n, method)
if nargin < 3
    method = 'linear';
end
n = normalizeLength(n, 2, 4096);
cmap = cleanCmap(cmap);
if size(cmap, 1) == n
    return
end
if size(cmap, 1) < 2
    cmap = repmat(cmap(1, :), n, 1);
    return
end

x = linspace(0, 1, size(cmap, 1));
xi = linspace(0, 1, n);
try
    cmap = interp1(x, cmap, xi, method);
catch
    cmap = interp1(x, cmap, xi, 'linear');
end
cmap = cleanCmap(cmap);
end

function [img, source, canceled] = resolveImage(imageInput)
canceled = false;
source = 'input array';
if isempty(imageInput)
    [fileName, folderName] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', ...
        'Image files (*.png,*.jpg,*.tif,*.bmp)'; '*.*', 'All files'}, 'Select image');
    if isequal(fileName, 0)
        canceled = true;
        img = [];
        source = '';
        return
    end
    imageInput = fullfile(folderName, fileName);
end

if ischar(imageInput) || isstring(imageInput)
    source = char(imageInput);
    [imgRaw, map] = imread(source);
    if ~isempty(map)
        imgRaw = ind2rgb(imgRaw, map);
    end
    img = imageToDoubleRgb(imgRaw);
else
    img = imageToDoubleRgb(imageInput);
end
end

function img = imageToDoubleRgb(img)
if ismatrix(img)
    img = repmat(img, 1, 1, 3);
elseif size(img, 3) > 3
    img = img(:, :, 1:3);
end

if isfloat(img)
    img = double(img);
    if max(img(:)) > 1
        img = img ./ 255;
    end
elseif isa(img, 'uint8')
    img = double(img) ./ 255;
elseif isa(img, 'uint16')
    img = double(img) ./ 65535;
else
    img = double(img);
    maxValue = max(img(:));
    if maxValue > 0
        img = img ./ maxValue;
    end
end
img = cleanCmap(img);
end

function points = interactivePickPoints(img, prompt, maxPoints)
points = zeros(0, 2);
fig = figure('Name', prompt, 'NumberTitle', 'off', 'Color', 'white');
ax = axes('Parent', fig);
image(ax, img);
axis(ax, 'image');
axis(ax, 'off');
title(ax, prompt, 'FontName', 'Arial', 'FontWeight', 'normal');
hold(ax, 'on');

while isvalid(fig) && size(points, 1) < maxPoints
    try
        [x, y, button] = ginput(1);
    catch
        break
    end
    if isempty(x) || isempty(button)
        break
    end
    points(end + 1, :) = [x y]; %#ok<AGROW>
    plot(ax, x, y, 'w+', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(ax, x, y, 'ko', 'MarkerSize', 12, 'LineWidth', 1);
    text(ax, x + 4, y, sprintf('%d', size(points, 1)), 'Color', 'w', ...
        'FontName', 'Arial', 'FontWeight', 'bold');
end
end

function rgb = sampleImagePoints(img, points)
points = normalizePointArray(points);
if isempty(points)
    rgb = zeros(0, 3);
    return
end

[height, width, ~] = size(img);
x = round(points(:, 1));
y = round(points(:, 2));
x = min(width, max(1, x));
y = min(height, max(1, y));
rgb = zeros(numel(x), 3);
for k = 1:numel(x)
    rgb(k, :) = reshape(img(y(k), x(k), :), 1, 3);
end
rgb = cleanCmap(rgb);
end

function cmap = sampleColorbarLine(img, endpoints, n)
endpoints = normalizePointArray(endpoints);
n = normalizeLength(n, 2, 4096);
if size(endpoints, 1) < 2
    error('colorEngine:ColorbarEndpoints', 'At least two endpoints are required.');
end

x = linspace(endpoints(1, 1), endpoints(2, 1), n);
y = linspace(endpoints(1, 2), endpoints(2, 2), n);
cmap = bilinearSampleRgb(img, x, y);
end

function rgb = bilinearSampleRgb(img, x, y)
[height, width, ~] = size(img);
x = min(width, max(1, x(:)));
y = min(height, max(1, y(:)));

x1 = floor(x);
x2 = min(width, x1 + 1);
y1 = floor(y);
y2 = min(height, y1 + 1);
dx = x - x1;
dy = y - y1;

rgb = zeros(numel(x), 3);
for k = 1:numel(x)
    c11 = reshape(img(y1(k), x1(k), :), 1, 3);
    c21 = reshape(img(y1(k), x2(k), :), 1, 3);
    c12 = reshape(img(y2(k), x1(k), :), 1, 3);
    c22 = reshape(img(y2(k), x2(k), :), 1, 3);
    rgb(k, :) = (1 - dx(k)) * (1 - dy(k)) * c11 + ...
        dx(k) * (1 - dy(k)) * c21 + ...
        (1 - dx(k)) * dy(k) * c12 + ...
        dx(k) * dy(k) * c22;
end
rgb = cleanCmap(rgb);
end

function palette = extractThemeGrid(img, n)
pixels = reshape(imageToDoubleRgb(img), [], 3);
pixels = downsampleRows(pixels, 60000);
quantized = round(pixels * 15) / 15;
[uniqueColors, ~, groupIndex] = unique(quantized, 'rows');
counts = accumarray(groupIndex, 1);
[~, order] = sort(counts, 'descend');
candidateColors = uniqueColors(order, :);
candidateCounts = counts(order);

selected = greedyDistinctColors(candidateColors, candidateCounts, n, 0.09);
if size(selected, 1) < n
    fillCount = min(n - size(selected, 1), size(candidateColors, 1));
    selected = [selected; candidateColors(1:fillCount, :)];
end
palette = cleanCmap(selected(1:n, :));
end

function palette = extractThemeKmeans(img, n)
pixels = reshape(imageToDoubleRgb(img), [], 3);
pixels = downsampleRows(pixels, 50000);
pixels = pixels(all(isfinite(pixels), 2), :);
if size(pixels, 1) < n
    palette = resamplePalette(pixels, n, 'linear');
    return
end

quantized = round(pixels * 255) / 255;
uniqueColors = unique(quantized, 'rows', 'stable');
if size(uniqueColors, 1) <= n
    palette = resamplePalette(uniqueColors, n, 'linear');
    return
end

rngState = rng;
cleanupObj = onCleanup(@() rng(rngState));
rng(7, 'twister');
if exist('kmeans', 'file') == 2
    try
        [idx, centers] = kmeans(pixels, n, 'MaxIter', 300, 'Replicates', 3, ...
            'Display', 'off', 'Start', 'plus');
    catch
        [idx, centers] = simpleKmeans(pixels, n, 60);
    end
else
    [idx, centers] = simpleKmeans(pixels, n, 60);
end
clear cleanupObj

counts = accumarray(idx, 1, [n 1], @sum, 0);
[~, order] = sort(counts, 'descend');
palette = cleanCmap(centers(order, :));
end

function [idx, centers] = simpleKmeans(pixels, n, maxIter)
count = size(pixels, 1);
seedIndex = unique(round(linspace(1, count, n)));
while numel(seedIndex) < n
    seedIndex(end + 1) = min(count, numel(seedIndex) + 1); %#ok<AGROW>
end
centers = pixels(seedIndex(1:n), :);
idx = ones(count, 1);

for iter = 1:maxIter
    distances = squaredDistances(pixels, centers);
    [~, newIdx] = min(distances, [], 2);
    if iter > 1 && isequal(newIdx, idx)
        break
    end
    idx = newIdx;
    for k = 1:n
        mask = idx == k;
        if any(mask)
            centers(k, :) = mean(pixels(mask, :), 1);
        end
    end
end
centers = cleanCmap(centers);
end

function distances = squaredDistances(a, b)
distances = zeros(size(a, 1), size(b, 1));
for k = 1:size(b, 1)
    diffValue = a - b(k, :);
    distances(:, k) = sum(diffValue .^ 2, 2);
end
end

function rows = downsampleRows(rows, maxRows)
if size(rows, 1) <= maxRows
    return
end
index = unique(round(linspace(1, size(rows, 1), maxRows)));
rows = rows(index, :);
end

function selected = greedyDistinctColors(colors, counts, n, minDistance)
selected = zeros(0, 3);
for k = 1:size(colors, 1)
    color = colors(k, :);
    if isempty(selected)
        selected = color;
    else
        distances = sqrt(sum((selected - color) .^ 2, 2));
        if all(distances >= minDistance)
            selected(end + 1, :) = color; %#ok<AGROW>
        end
    end
    if size(selected, 1) >= n
        break
    end
end

if size(selected, 1) < n
    [~, order] = sort(counts, 'descend');
    for k = 1:numel(order)
        color = colors(order(k), :);
        selected(end + 1, :) = color; %#ok<AGROW>
        if size(selected, 1) >= n
            break
        end
    end
end
selected = unique(selected, 'rows', 'stable');
end

function showPalette(cmap, figureTitle, showHex)
cmap = cleanCmap(cmap);
n = size(cmap, 1);
fig = figure('Name', figureTitle, 'NumberTitle', 'off', 'Color', 'white');
ax = axes('Parent', fig);
if n <= 64
    axis(ax, [0 n 0 1]);
    axis(ax, 'off');
    hold(ax, 'on');
    for k = 1:n
        rectangle(ax, 'Position', [k - 1, 0, 1, 1], 'FaceColor', cmap(k, :), ...
            'EdgeColor', 'none');
        if showHex && n <= 24
            labelColor = readableTextColor(cmap(k, :));
            text(ax, k - 0.5, 0.5, rgb2hex(cmap(k, :)), 'Rotation', 90, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Color', labelColor, 'FontName', 'Arial', 'FontSize', 9);
        end
    end
else
    imagesc(ax, linspace(0, 1, n), [0 1], repmat(1:n, 24, 1));
    colormap(ax, cmap);
    set(ax, 'CLim', [1 n], 'YTick', []);
    xlabel(ax, 'normalized value', 'FontName', 'Arial');
end
title(ax, figureTitle, 'FontName', 'Arial', 'FontWeight', 'normal');
end

function showImageWithPalette(img, palette, figureTitle)
fig = figure('Name', figureTitle, 'NumberTitle', 'off', 'Color', 'white');
layout = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
ax1 = nexttile(layout);
image(ax1, img);
axis(ax1, 'image');
axis(ax1, 'off');
title(ax1, figureTitle, 'FontName', 'Arial', 'FontWeight', 'normal');
ax2 = nexttile(layout);
n = size(palette, 1);
axis(ax2, [0 n 0 1]);
axis(ax2, 'off');
hold(ax2, 'on');
for k = 1:n
    rectangle(ax2, 'Position', [k - 1, 0, 1, 1], 'FaceColor', palette(k, :), ...
        'EdgeColor', 'none');
    text(ax2, k - 0.5, 0.5, rgb2hex(palette(k, :)), 'Rotation', 90, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'Color', readableTextColor(palette(k, :)), 'FontName', 'Arial', 'FontSize', 9);
end
end

function showPaletteCatalog(startID, endID)
ids = startID:endID;
fig = figure('Name', sprintf('ColorKit palette catalog %d-%d', startID, endID), ...
    'NumberTitle', 'off', 'Color', 'white');
cols = min(4, numel(ids));
rows = ceil(numel(ids) / cols);
layout = tiledlayout(fig, rows, cols, 'Padding', 'compact', 'TileSpacing', 'compact');
for k = 1:numel(ids)
    ax = nexttile(layout);
    cmap = makeColorPalette(ids(k));
    strip = repmat(1:size(cmap, 1), 12, 1);
    imagesc(ax, strip);
    colormap(ax, cmap);
    set(ax, 'CLim', [1 size(cmap, 1)], 'XTick', [], 'YTick', []);
    title(ax, sprintf('%d (%d)', ids(k), size(cmap, 1)), ...
        'FontName', 'Arial', 'FontWeight', 'normal', 'FontSize', 9);
    box(ax, 'on');
end
end

function color = readableTextColor(rgb)
lum = 0.2126 * rgb(1) + 0.7152 * rgb(2) + 0.0722 * rgb(3);
if lum > 0.55
    color = [0.05 0.05 0.05];
else
    color = [0.95 0.95 0.95];
end
end

function rgb = hexListToRgb(hexList)
rgb = zeros(numel(hexList), 3);
for k = 1:numel(hexList)
    rgb(k, :) = hex2rgb(hexList{k});
end
end

function rgb = hex2rgb(hexValue)
hexValue = char(strtrim(string(hexValue)));
if startsWith(hexValue, '#')
    hexValue = hexValue(2:end);
end
if numel(hexValue) ~= 6 || any(~isstrprop(hexValue, 'xdigit'))
    error('colorEngine:InvalidHex', 'Invalid hex color.');
end
rgb = [hex2dec(hexValue(1:2)), hex2dec(hexValue(3:4)), hex2dec(hexValue(5:6))] ./ 255;
end

function hexValue = rgb2hex(rgb)
rgb = clip01(double(rgb(:)'));
if numel(rgb) < 3
    rgb(1, end + 1:3) = 0;
end
rgb = round(rgb(1:3) * 255);
hexValue = sprintf('#%02X%02X%02X', rgb(1), rgb(2), rgb(3));
end

function cmap = cleanCmap(cmap)
cmap = real(double(cmap));
cmap(~isfinite(cmap)) = 0;
cmap = clip01(cmap);
end

function value = clip01(value)
value = min(1, max(0, value));
end

function n = normalizeLength(n, minValue, maxValue)
if nargin < 2
    minValue = 2;
end
if nargin < 3
    maxValue = 4096;
end
if isempty(n) || ~isscalar(n) || ~isfinite(n)
    n = 256;
end
n = max(minValue, min(maxValue, round(double(n))));
end

function showHelp()
fprintf('ColorKit internal color engine\n');
fprintf('  C = colorEngine(''palette'', id, ''map'', n, ''seka'', 1)\n');
fprintf('  C = colorEngine(''gradient'', id, ''map'', n, ''seka'', 1)\n');
fprintf('  C = colorEngine(''copy'', ''seka'', 1)\n');
fprintf('  C = colorEngine(''copymap'', sampleN, ''map'', n, ''seka'', 1)\n');
fprintf('  C = colorEngine(''img2palette1'', n, ''seka'', 1)\n');
fprintf('  C = colorEngine(''img2palette2'', n, ''seka'', 1)\n');
fprintf('  colorEngine(''view'', ''palette'', 1, 24)\n');
end



