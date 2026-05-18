function varargout = ColormapDesigner(varargin)
% ColormapDesigner - Interactive MATLAB colormap designer.
%
% Author: zhaoyh, 2026.
% Email: zhao2025@mail.sustech.edu.cn
%
% Usage:
%   ColormapDesigner
%       Opens the GUI for creating, editing, previewing, applying, and
%       exporting scientific colormaps.
%
%   ColormapDesigner('__selftest__')
%       Runs internal non-GUI checks for core color conversion,
%       interpolation, palette, and adjustment helpers.

if nargin > 0 && (ischar(varargin{1}) || isstring(varargin{1}))
    command = char(varargin{1});
    if strcmpi(command, '__selftest__')
        runSelfTests();
        if nargout > 0
            varargout{1} = true;
        end
        return
    end
end

app = createUI();
setApp(app);
updateColormap(app.Figure, true);

if nargout > 0
    varargout{1} = app.Figure;
end
end

function runSelfTests()
fprintf('Running ColormapDesigner self-tests...\n');

names = getPaletteNames();
assert(ismember('Blue', names), 'Palette list must include Blue.');
assert(ismember('BlueWhiteRed', names), 'Palette list must include BlueWhiteRed.');
assert(~isempty(getPaletteNames('All', 'blue')), 'Palette search must find blue palettes.');
assert(~isempty(getPaletteNames('All', 'categorical')), 'Palette search must find categorical palettes.');

nodes = loadPaletteColormap('BlueWhiteRed');
assert(size(nodes, 2) == 4, 'Palette nodes must be an N-by-4 array.');
assert(size(nodes, 1) >= 2, 'Palette nodes must include at least two control points.');

rgb = hex2rgb('#3B6EA8');
assert(all(abs(rgb - [59 110 168] ./ 255) < 1e-12), 'hex2rgb returned the wrong RGB triplet.');
assert(strcmp(rgb2hex(rgb), '#3B6EA8'), 'rgb2hex returned the wrong hex value.');

rawTable = table([1.2; -0.1; 0.5], [2; 0.5; -1], [0; 1.4; 0.5], ...
    [0.1; 0.2; 1.5], ["#000000"; "bad"; "#FFFFFF"], ...
    'VariableNames', {'Position', 'R', 'G', 'B', 'Hex'});
cleanTable = sanitizeNodeTable(rawTable);
assert(height(cleanTable) >= 2, 'Sanitized table must keep at least two nodes.');
assert(all(cleanTable.Position >= 0 & cleanTable.Position <= 1), 'Positions must be clipped to [0, 1].');
assert(all(cleanTable.R >= 0 & cleanTable.R <= 1), 'R values must be clipped to [0, 1].');
assert(all(cleanTable.G >= 0 & cleanTable.G <= 1), 'G values must be clipped to [0, 1].');
assert(all(cleanTable.B >= 0 & cleanTable.B <= 1), 'B values must be clipped to [0, 1].');

cmap = interpolateColormap(nodes, 64, 'linear RGB');
assert(isequal(size(cmap), [64 3]), 'Interpolated colormap must be N-by-3.');
assert(all(isfinite(cmap(:))), 'Interpolated colormap must be finite.');
assert(all(cmap(:) >= 0 & cmap(:) <= 1), 'Interpolated colormap must be clipped to [0, 1].');

options = struct('Length', 128, 'Interpolation', 'pchip RGB', 'Reverse', false, ...
    'Gamma', 1.15, 'Brightness', 0.05, 'Contrast', 1.05, 'Saturation', 0.85, ...
    'TruncateStart', 0.1, 'TruncateEnd', 0.9, 'CenterLock', true, 'CenterColor', [1 1 1]);
cmap2 = updateColormapFromNodes(nodes, options);
assert(isequal(size(cmap2), [128 3]), 'Updated colormap must respect requested length.');
assert(all(isfinite(cmap2(:))), 'Updated colormap must be finite.');
assert(all(cmap2(:) >= 0 & cmap2(:) <= 1), 'Updated colormap must be clipped to [0, 1].');

adjusted = adjustBrightnessContrastSaturation(cmap, 0.1, 1.1, 0.8, 1.0);
assert(isequal(size(adjusted), size(cmap)), 'Adjusted colormap must keep the original size.');
assert(all(adjusted(:) >= 0 & adjusted(:) <= 1), 'Adjusted colormap must be clipped to [0, 1].');

fprintf('ColormapDesigner self-tests passed.\n');
end

function app = createUI()
app = struct();
app.CurrentCmap = parulaFallback(256);
app.SelectedRows = [];
app.PreviewData = makePreviewData();

app.Figure = uifigure('Name', 'ColormapDesigner', ...
    'Position', [80 80 1320 780], ...
    'Color', 'white');
app.Figure.CloseRequestFcn = @(src, ~) delete(src);

mainGrid = uigridlayout(app.Figure, [1 2]);
mainGrid.ColumnWidth = {360, '1x'};
mainGrid.RowHeight = {'1x'};
mainGrid.Padding = [10 10 10 10];
mainGrid.ColumnSpacing = 12;
mainGrid.BackgroundColor = 'white';

controlPanel = uipanel(mainGrid, 'Title', 'Controls', ...
    'FontName', 'Arial', 'FontWeight', 'bold', 'BackgroundColor', 'white');
controlPanel.Layout.Row = 1;
controlPanel.Layout.Column = 1;
try
    controlPanel.Scrollable = 'on';
catch
end

controlGrid = uigridlayout(controlPanel, [31 2]);
controlGrid.ColumnWidth = {120, '1x'};
controlGrid.RowHeight = {30, 94, 30, 30, 24, 205, 32, 30, 30, 30, 30, 30, 30, 30, 30, 32, 32, 32, 32, 32, 32, 32, 30, 30, 30, 30, 30, 30, 30, 34, 24};
controlGrid.Padding = [10 8 10 8];
controlGrid.RowSpacing = 6;
controlGrid.ColumnSpacing = 8;
controlGrid.BackgroundColor = 'white';

titleLabel = uilabel(controlGrid, 'Text', 'Scientific Colormap Designer', ...
    'FontName', 'Arial', 'FontSize', 15, 'FontWeight', 'bold');
titleLabel.Layout.Row = 1;
titleLabel.Layout.Column = [1 2];

paletteGrid = uigridlayout(controlGrid, [3 2]);
paletteGrid.Layout.Row = 2;
paletteGrid.Layout.Column = [1 2];
paletteGrid.ColumnWidth = {82, '1x'};
paletteGrid.RowHeight = {26, 26, 26};
paletteGrid.Padding = [0 0 0 0];
paletteGrid.RowSpacing = 4;
paletteGrid.ColumnSpacing = 8;
paletteGrid.BackgroundColor = 'white';

uilabel(paletteGrid, 'Text', 'Palette group', 'FontName', 'Arial', ...
    'HorizontalAlignment', 'right');
app.PaletteGroupDropDown = uidropdown(paletteGrid, 'Items', getPaletteGroups(), ...
    'Value', 'All', 'FontName', 'Arial');
app.PaletteGroupDropDown.Layout.Row = 1;
app.PaletteGroupDropDown.Layout.Column = 2;
app.PaletteGroupDropDown.ValueChangedFcn = @(~, ~) onPaletteFilterChanged(app.Figure);

uilabel(paletteGrid, 'Text', 'Search', 'FontName', 'Arial', ...
    'HorizontalAlignment', 'right');
app.SearchEditField = uieditfield(paletteGrid, 'text', ...
    'Placeholder', 'blue, red, diverging, categorical', 'FontName', 'Arial');
app.SearchEditField.Layout.Row = 2;
app.SearchEditField.Layout.Column = 2;
app.SearchEditField.ValueChangedFcn = @(~, ~) onPaletteFilterChanged(app.Figure);

uilabel(paletteGrid, 'Text', 'Palette', 'FontName', 'Arial', ...
    'HorizontalAlignment', 'right');
initialPresetNames = getPaletteNames('All', '');
app.PaletteDropDown = uidropdown(paletteGrid, 'Items', initialPresetNames, ...
    'Value', 'Blue', 'FontName', 'Arial');
app.PaletteDropDown.Layout.Row = 3;
app.PaletteDropDown.Layout.Column = 2;
app.PaletteDropDown.ValueChangedFcn = @(~, ~) onPaletteChanged(app.Figure);

makeLabel(controlGrid, 3, 'Length N');
app.LengthDropDown = uidropdown(controlGrid, 'Items', {'64', '128', '256', '512', '1024'}, ...
    'Value', '256', 'FontName', 'Arial');
app.LengthDropDown.Layout.Row = 3;
app.LengthDropDown.Layout.Column = 2;
app.LengthDropDown.ValueChangedFcn = @(~, ~) updateColormap(app.Figure, false);

makeLabel(controlGrid, 4, 'Interpolation');
app.InterpDropDown = uidropdown(controlGrid, ...
    'Items', {'linear RGB', 'pchip RGB', 'spline RGB', 'perceptual-like'}, ...
    'Value', 'linear RGB', 'FontName', 'Arial');
app.InterpDropDown.Layout.Row = 4;
app.InterpDropDown.Layout.Column = 2;
app.InterpDropDown.ValueChangedFcn = @(~, ~) updateColormap(app.Figure, false);

nodeLabel = uilabel(controlGrid, 'Text', 'Color nodes: position, RGB, Hex', ...
    'FontName', 'Arial', 'FontWeight', 'bold');
nodeLabel.Layout.Row = 5;
nodeLabel.Layout.Column = [1 2];

app.NodeTable = uitable(controlGrid, 'Data', nodesToTable(loadPaletteColormap(app.PaletteDropDown.Value)), ...
    'ColumnName', {'position', 'R', 'G', 'B', 'Hex'}, ...
    'ColumnEditable', [true true true true true], ...
    'FontName', 'Arial');
app.NodeTable.Layout.Row = 6;
app.NodeTable.Layout.Column = [1 2];
app.NodeTable.CellEditCallback = @(~, event) onTableEdited(app.Figure, event);
try
    app.NodeTable.SelectionChangedFcn = @(~, event) onTableSelection(app.Figure, event);
catch
end

app.AddNodeButton = uibutton(controlGrid, 'Text', 'Add node', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) addNode(app.Figure));
app.AddNodeButton.Layout.Row = 7;
app.AddNodeButton.Layout.Column = 1;
app.DeleteNodeButton = uibutton(controlGrid, 'Text', 'Delete node', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) deleteNode(app.Figure));
app.DeleteNodeButton.Layout.Row = 7;
app.DeleteNodeButton.Layout.Column = 2;

app.ReverseCheckBox = uicheckbox(controlGrid, 'Text', 'Reverse colormap', ...
    'FontName', 'Arial', 'ValueChangedFcn', @(~, ~) updateColormap(app.Figure, false));
app.ReverseCheckBox.Layout.Row = 8;
app.ReverseCheckBox.Layout.Column = [1 2];

[app.GammaSlider, app.GammaValue] = addSlider(controlGrid, 9, 'Gamma', [0.2 3], 1, app.Figure);
[app.BrightnessSlider, app.BrightnessValue] = addSlider(controlGrid, 10, 'Brightness', [-0.5 0.5], 0, app.Figure);
[app.ContrastSlider, app.ContrastValue] = addSlider(controlGrid, 11, 'Contrast', [0 2], 1, app.Figure);
[app.SaturationSlider, app.SaturationValue] = addSlider(controlGrid, 12, 'Saturation', [0 2], 1, app.Figure);
[app.TruncateStartSlider, app.TruncateStartValue] = addSlider(controlGrid, 13, 'Truncate start', [0 0.95], 0, app.Figure);
[app.TruncateEndSlider, app.TruncateEndValue] = addSlider(controlGrid, 14, 'Truncate end', [0.05 1], 1, app.Figure);

app.CenterLockCheckBox = uicheckbox(controlGrid, 'Text', 'Center color locking', ...
    'FontName', 'Arial', 'ValueChangedFcn', @(~, ~) updateColormap(app.Figure, false));
app.CenterLockCheckBox.Layout.Row = 15;
app.CenterLockCheckBox.Layout.Column = [1 2];
makeLabel(controlGrid, 16, 'Center color');
app.CenterColorDropDown = uidropdown(controlGrid, 'Items', {'White', 'Light gray'}, ...
    'Value', 'White', 'FontName', 'Arial');
app.CenterColorDropDown.Layout.Row = 16;
app.CenterColorDropDown.Layout.Column = 2;
app.CenterColorDropDown.ValueChangedFcn = @(~, ~) updateColormap(app.Figure, false);

app.ExportWorkspaceButton = uibutton(controlGrid, 'Text', 'Export workspace', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) exportToWorkspace(app.Figure));
app.ExportWorkspaceButton.Layout.Row = 17;
app.ExportWorkspaceButton.Layout.Column = [1 2];

app.ExportMatButton = uibutton(controlGrid, 'Text', 'Save MAT', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) exportToFile(app.Figure, 'mat'));
app.ExportMatButton.Layout.Row = 18;
app.ExportMatButton.Layout.Column = 1;
app.ExportTextButton = uibutton(controlGrid, 'Text', 'Save CSV/TXT', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) exportToFile(app.Figure, 'text'));
app.ExportTextButton.Layout.Row = 18;
app.ExportTextButton.Layout.Column = 2;

app.GenerateFunctionButton = uibutton(controlGrid, 'Text', 'Generate .m function', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) generateMFunction(app.Figure));
app.GenerateFunctionButton.Layout.Row = 19;
app.GenerateFunctionButton.Layout.Column = [1 2];

app.CopyCodeButton = uibutton(controlGrid, 'Text', 'Copy colormap code', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) copyColormapCode(app.Figure));
app.CopyCodeButton.Layout.Row = 20;
app.CopyCodeButton.Layout.Column = [1 2];

app.ApplyFigureButton = uibutton(controlGrid, 'Text', 'Apply to current figure', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) applyToCurrentFigure(app.Figure, false));
app.ApplyFigureButton.Layout.Row = 21;
app.ApplyFigureButton.Layout.Column = [1 2];

app.ApplyAxesButton = uibutton(controlGrid, 'Text', 'Apply to selected axes', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) applyToSelectedAxes(app.Figure, false));
app.ApplyAxesButton.Layout.Row = 22;
app.ApplyAxesButton.Layout.Column = [1 2];

app.ReverseApplyButton = uibutton(controlGrid, 'Text', 'Reverse and apply', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) applyToCurrentFigure(app.Figure, true));
app.ReverseApplyButton.Layout.Row = 23;
app.ReverseApplyButton.Layout.Column = [1 2];

app.ExportPreviewButton = uibutton(controlGrid, 'Text', 'Export preview PNG/PDF', 'FontName', 'Arial', ...
    'ButtonPushedFcn', @(~, ~) exportPreviewFigure(app.Figure));
app.ExportPreviewButton.Layout.Row = 24;
app.ExportPreviewButton.Layout.Column = [1 2];

hintLabel = uilabel(controlGrid, 'Text', ...
    'Palette groups: Built-in basics; Sequential one-way; Diverging centered; Categorical classes; Cyclic phase/angle; Grayscale print checks; Custom user-defined or user-named groups. RGB values use 0 to 1.', ...
    'FontName', 'Arial', 'FontSize', 11, 'WordWrap', 'on');
hintLabel.Layout.Row = [25 27];
hintLabel.Layout.Column = [1 2];

app.StatusLabel = uilabel(controlGrid, 'Text', 'Ready.', 'FontName', 'Arial', ...
    'FontSize', 11, 'FontColor', [0.2 0.2 0.2], 'WordWrap', 'on');
app.StatusLabel.Layout.Row = [28 31];
app.StatusLabel.Layout.Column = [1 2];

previewGrid = uigridlayout(mainGrid, [4 2]);
previewGrid.Layout.Row = 1;
previewGrid.Layout.Column = 2;
previewGrid.RowHeight = {76, '1x', '1x', '1x'};
previewGrid.ColumnWidth = {'1x', '1x'};
previewGrid.Padding = [0 0 0 0];
previewGrid.RowSpacing = 10;
previewGrid.ColumnSpacing = 10;
previewGrid.BackgroundColor = 'white';

app.ColorbarAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.ColorbarAxes.Layout.Row = 1;
app.ColorbarAxes.Layout.Column = [1 2];
title(app.ColorbarAxes, 'Current colormap', 'FontName', 'Arial', 'FontWeight', 'normal');

app.SequentialAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.SequentialAxes.Layout.Row = 2;
app.SequentialAxes.Layout.Column = 1;
title(app.SequentialAxes, 'sequential data', 'FontName', 'Arial', 'FontWeight', 'normal');

app.DivergingAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.DivergingAxes.Layout.Row = 2;
app.DivergingAxes.Layout.Column = 2;
title(app.DivergingAxes, 'diverging field', 'FontName', 'Arial', 'FontWeight', 'normal');

app.CategoricalAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.CategoricalAxes.Layout.Row = 3;
app.CategoricalAxes.Layout.Column = 1;
title(app.CategoricalAxes, 'categorical line plot', 'FontName', 'Arial', 'FontWeight', 'normal');

app.SpectrumAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.SpectrumAxes.Layout.Row = 3;
app.SpectrumAxes.Layout.Column = 2;
title(app.SpectrumAxes, 'time-frequency texture', 'FontName', 'Arial', 'FontWeight', 'normal');

app.SignedFieldAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.SignedFieldAxes.Layout.Row = 4;
app.SignedFieldAxes.Layout.Column = 1;
title(app.SignedFieldAxes, 'positive/negative field', 'FontName', 'Arial', 'FontWeight', 'normal');

app.GrayscaleAxes = uiaxes(previewGrid, 'FontName', 'Arial', 'Color', 'white');
app.GrayscaleAxes.Layout.Row = 4;
app.GrayscaleAxes.Layout.Column = 2;
title(app.GrayscaleAxes, 'grayscale print check', 'FontName', 'Arial', 'FontWeight', 'normal');

formatAxes([app.ColorbarAxes, app.SequentialAxes, app.DivergingAxes, ...
    app.CategoricalAxes, app.SpectrumAxes, app.SignedFieldAxes, app.GrayscaleAxes]);
end

function label = makeLabel(parent, row, textValue)
label = uilabel(parent, 'Text', textValue, 'FontName', 'Arial', ...
    'HorizontalAlignment', 'right');
label.Layout.Row = row;
label.Layout.Column = 1;
end

function [slider, valueLabel] = addSlider(parent, row, labelText, limits, value, fig)
label = makeLabel(parent, row, labelText);
label.HorizontalAlignment = 'right';

sliderGrid = uigridlayout(parent, [1 2]);
sliderGrid.Layout.Row = row;
sliderGrid.Layout.Column = 2;
sliderGrid.ColumnWidth = {'1x', 46};
sliderGrid.RowHeight = {'1x'};
sliderGrid.Padding = [0 0 0 0];
sliderGrid.ColumnSpacing = 6;
sliderGrid.BackgroundColor = 'white';

slider = uislider(sliderGrid, 'Limits', limits, 'Value', value);
slider.Layout.Row = 1;
slider.Layout.Column = 1;
slider.MajorTicks = [];
slider.ValueChangingFcn = @(src, event) onSliderChanging(fig, src, event);
slider.ValueChangedFcn = @(~, ~) updateColormap(fig, false);

valueLabel = uilabel(sliderGrid, 'Text', sprintf('%.2f', value), ...
    'FontName', 'Arial', 'FontSize', 11, 'HorizontalAlignment', 'right');
valueLabel.Layout.Row = 1;
valueLabel.Layout.Column = 2;
end

function categories = getPaletteGroups()
try
    categories = cellstr(ColorKit('categories'));
catch
    categories = {'All'};
end
end

function names = getPaletteNames(category, query)
if nargin < 1 || isempty(category)
    category = 'All';
end
if nargin < 2
    query = '';
end
try
    catalog = ColorKit('catalog');
    if ~strcmpi(string(category), "All")
        catalog = catalog(strcmpi(catalog.PaletteGroup, string(category)), :);
    end
    query = strtrim(string(query));
    if query ~= ""
        haystack = lower(catalog.Name + " " + catalog.PaletteGroup + " " + ...
            catalog.Type + " " + catalog.RecommendedUse + " " + catalog.SourceStyle);
        catalog = catalog(contains(haystack, lower(query)), :);
    end
    names = cellstr(catalog.Name);
    if isempty(names)
        names = cellstr(ColorKit('catalog').Name(1));
    end
catch
    names = {'Blue'};
end
end

function nodes = loadPaletteColormap(name)
try
    cmap = getPresetColormap(string(name), 256);
catch
    cmap = parulaFallback(256);
end
nodes = cmapToNodes(cmap, min(15, size(cmap, 1)));
nodes = sanitizeNodesArray(nodes);
end

function cmap = updateColormapFromNodes(nodes, options)
if nargin < 2
    options = struct();
end

n = getOption(options, 'Length', 256);
n = normalizeLength(n);
method = getOption(options, 'Interpolation', 'linear RGB');
reverseMap = logical(getOption(options, 'Reverse', false));
gammaValue = max(0.05, double(getOption(options, 'Gamma', 1)));
brightness = double(getOption(options, 'Brightness', 0));
contrast = double(getOption(options, 'Contrast', 1));
saturation = double(getOption(options, 'Saturation', 1));
truncateStart = clip01(double(getOption(options, 'TruncateStart', 0)));
truncateEnd = clip01(double(getOption(options, 'TruncateEnd', 1)));
centerLock = logical(getOption(options, 'CenterLock', false));
centerColor = double(getOption(options, 'CenterColor', [1 1 1]));

if truncateStart >= truncateEnd
    truncateStart = 0;
    truncateEnd = 1;
end

baseN = max(n, 512);
base = interpolateColormap(nodes, baseN, method);
baseX = linspace(0, 1, size(base, 1));
targetX = linspace(truncateStart, truncateEnd, n);
cmap = interp1(baseX, base, targetX, 'linear');

if centerLock
    cmap = applyCenterLock(cmap, centerColor);
end

if reverseMap
    cmap = flipud(cmap);
end

cmap = cmap .^ gammaValue;
cmap = adjustBrightnessContrastSaturation(cmap, brightness, contrast, saturation, 1);
cmap = cleanCmap(cmap);
end

function cmap = interpolateColormap(nodes, n, method)
if nargin < 2 || isempty(n)
    n = 256;
end
if nargin < 3 || isempty(method)
    method = 'linear RGB';
end

n = normalizeLength(n);
nodes = sanitizeNodesArray(nodes);
pos = nodes(:, 1);
rgb = nodes(:, 2:4);

if pos(1) > 0
    pos = [0; pos];
    rgb = [rgb(1, :); rgb];
end
if pos(end) < 1
    pos = [pos; 1];
    rgb = [rgb; rgb(end, :)];
end

x = linspace(0, 1, n)';
methodKey = lower(strtrim(char(method)));
switch methodKey
    case 'pchip rgb'
        cmap = interp1(pos, rgb, x, 'pchip');
    case 'spline rgb'
        cmap = interp1(pos, rgb, x, 'spline');
    case 'perceptual-like'
        cmap = interpolatePerceptualLike(pos, rgb, x);
    otherwise
        cmap = interp1(pos, rgb, x, 'linear');
end

cmap = cleanCmap(cmap);
end

function cmap = interpolatePerceptualLike(pos, rgb, x)
usedLab = false;
cmap = [];

if exist('rgb2lab', 'file') == 2 && exist('lab2rgb', 'file') == 2
    try
        lab = rgb2lab(reshape(rgb, [], 1, 3));
        lab = reshape(lab, [], 3);
        interpLab = interp1(pos, lab, x, 'pchip');
        rgbImage = lab2rgb(reshape(interpLab, [], 1, 3));
        cmap = reshape(rgbImage, [], 3);
        usedLab = true;
    catch
        usedLab = false;
    end
end

if ~usedLab
    rgbLinear = max(0, min(1, rgb)) .^ 2.2;
    cmap = interp1(pos, rgbLinear, x, 'pchip') .^ (1 / 2.2);
end
end

function cmap = adjustBrightnessContrastSaturation(cmap, brightness, contrast, saturation, gammaValue)
if nargin < 2 || isempty(brightness)
    brightness = 0;
end
if nargin < 3 || isempty(contrast)
    contrast = 1;
end
if nargin < 4 || isempty(saturation)
    saturation = 1;
end
if nargin < 5 || isempty(gammaValue)
    gammaValue = 1;
end

cmap = cleanCmap(cmap);
cmap = cmap .^ max(0.05, gammaValue);
cmap = (cmap - 0.5) .* contrast + 0.5 + brightness;
cmap = cleanCmap(cmap);

hsvMap = rgb2hsv(cmap);
hsvMap(:, 2) = clip01(hsvMap(:, 2) .* saturation);
cmap = hsv2rgb(hsvMap);
cmap = cleanCmap(cmap);
end

function updateColormap(fig, refreshTable)
if nargin < 2
    refreshTable = false;
end

app = getApp(fig);
try
    cleanTable = sanitizeNodeTable(app.NodeTable.Data);
    if refreshTable
        app.NodeTable.Data = cleanTable;
    end

    options = readOptions(app);
    cmap = updateColormapFromNodes(tableToNodes(cleanTable), options);
    app.CurrentCmap = cmap;
    updateValueLabels(app);
    updatePreview(app);
    setStatus(app, sprintf('Updated %d-color colormap.', size(cmap, 1)));
catch err
    setStatus(app, ['Update failed: ' err.message]);
end
setApp(app);
end

function updatePreview(app)
cmap = app.CurrentCmap;
n = size(cmap, 1);

ax = app.ColorbarAxes;
cla(ax);
imagesc(ax, linspace(0, 1, n), [0 1], repmat(1:n, 12, 1));
colormap(ax, cmap);
set(ax, 'CLim', [1 n]);
ax.YTick = [];
ax.XLim = [0 1];
ax.Box = 'on';
xlabel(ax, 'normalized value', 'FontName', 'Arial');
title(ax, 'Current colormap', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = app.SequentialAxes;
cla(ax);
imagesc(ax, app.PreviewData.Sequential);
axis(ax, 'image');
colormap(ax, cmap);
colorbar(ax);
xlabel(ax, 'column', 'FontName', 'Arial');
ylabel(ax, 'row', 'FontName', 'Arial');
title(ax, 'sequential data', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = app.DivergingAxes;
cla(ax);
imagesc(ax, app.PreviewData.Diverging);
axis(ax, 'image');
limitValue = max(abs(app.PreviewData.Diverging(:)));
set(ax, 'CLim', [-limitValue limitValue]);
colormap(ax, cmap);
colorbar(ax);
title(ax, 'diverging field', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'x', 'FontName', 'Arial');
ylabel(ax, 'y', 'FontName', 'Arial');

ax = app.CategoricalAxes;
cla(ax);
lineColors = getPreviewLineColors(cmap, size(app.PreviewData.CategoricalLines, 1));
hold(ax, 'on');
for k = 1:size(app.PreviewData.CategoricalLines, 1)
    plot(ax, app.PreviewData.LineX, app.PreviewData.CategoricalLines(k, :), ...
        'LineWidth', 1.4, 'Color', lineColors(k, :));
end
hold(ax, 'off');
grid(ax, 'on');
title(ax, 'categorical line plot', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'sample', 'FontName', 'Arial');
ylabel(ax, 'value', 'FontName', 'Arial');

ax = app.SpectrumAxes;
cla(ax);
imagesc(ax, app.PreviewData.Time, app.PreviewData.Frequency, app.PreviewData.Spectrum);
axis(ax, 'xy');
colormap(ax, cmap);
colorbar(ax);
title(ax, 'time-frequency texture', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'time / offset', 'FontName', 'Arial');
ylabel(ax, 'frequency / wavenumber', 'FontName', 'Arial');

ax = app.SignedFieldAxes;
cla(ax);
imagesc(ax, app.PreviewData.FieldX, app.PreviewData.FieldY, app.PreviewData.SignedField);
axis(ax, 'image');
fieldLimit = max(abs(app.PreviewData.SignedField(:)));
set(ax, 'CLim', [-fieldLimit fieldLimit]);
colormap(ax, cmap);
colorbar(ax);
title(ax, 'positive/negative field', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'x', 'FontName', 'Arial');
ylabel(ax, 'y', 'FontName', 'Arial');

ax = app.GrayscaleAxes;
cla(ax);
grayCmap = rgbToGrayCmap(simulateColorblindPreview(cmap, 'deuteranopia'));
imagesc(ax, app.PreviewData.Sequential);
axis(ax, 'image');
colormap(ax, grayCmap);
colorbar(ax);
title(ax, 'grayscale / colorblind check', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'column', 'FontName', 'Arial');
ylabel(ax, 'row', 'FontName', 'Arial');

formatAxes([app.ColorbarAxes, app.SequentialAxes, app.DivergingAxes, ...
    app.CategoricalAxes, app.SpectrumAxes, app.SignedFieldAxes, app.GrayscaleAxes]);
drawnow limitrate;
end

function colors = getPreviewLineColors(cmap, count)
count = max(1, round(count));
if size(cmap, 1) >= count
    idx = unique(round(linspace(1, size(cmap, 1), count)));
    while numel(idx) < count
        idx(end + 1) = min(size(cmap, 1), numel(idx) + 1); %#ok<AGROW>
    end
    colors = cmap(idx(1:count), :);
else
    colors = repmat(cmap, ceil(count / size(cmap, 1)), 1);
    colors = colors(1:count, :);
end
colors = cleanCmap(colors);
end

function grayCmap = rgbToGrayCmap(cmap)
cmap = cleanCmap(cmap);
lum = 0.2126 .* cmap(:, 1) + 0.7152 .* cmap(:, 2) + 0.0722 .* cmap(:, 3);
grayCmap = repmat(lum, 1, 3);
grayCmap = cleanCmap(grayCmap);
end

function simulated = simulateColorblindPreview(cmap, mode)
% Approximate interface for color-vision deficiency preview.
% This intentionally avoids external dependencies and can be replaced by a
% more detailed simulator later without changing callers.
cmap = cleanCmap(cmap);
switch lower(string(mode))
    case "deuteranopia"
        matrix = [0.625 0.375 0.000; 0.700 0.300 0.000; 0.000 0.300 0.700];
    case "protanopia"
        matrix = [0.567 0.433 0.000; 0.558 0.442 0.000; 0.000 0.242 0.758];
    otherwise
        matrix = eye(3);
end
simulated = cleanCmap(cmap * matrix');
end

function exportToWorkspace(fig)
app = getApp(fig);
customCmap = app.CurrentCmap;
assignin('base', 'customCmap', customCmap);
setStatus(app, 'Exported current colormap to workspace variable customCmap.');
setApp(app);
end

function exportToFile(fig, mode)
app = getApp(fig);
cmap = app.CurrentCmap;

switch lower(mode)
    case 'mat'
        [fileName, folderName] = uiputfile({'*.mat', 'MAT file (*.mat)'}, ...
            'Save colormap as MAT', 'customCmap.mat');
        if isCanceled(fileName)
            setStatus(app, 'MAT export canceled.');
            setApp(app);
            return
        end
        customCmap = cmap;
        save(fullfile(folderName, fileName), 'customCmap');
        setStatus(app, ['Saved MAT file: ' fullfile(folderName, fileName)]);
    otherwise
        [fileName, folderName] = uiputfile({'*.csv', 'CSV file (*.csv)'; '*.txt', 'Text file (*.txt)'}, ...
            'Save colormap as text', 'customCmap.csv');
        if isCanceled(fileName)
            setStatus(app, 'Text export canceled.');
            setApp(app);
            return
        end
        target = fullfile(folderName, fileName);
        [~, ~, ext] = fileparts(target);
        writeRgbTable(cmap, target, ext);
        setStatus(app, ['Saved RGB table: ' target]);
end

setApp(app);
end

function writeRgbTable(cmap, target, ext)
if strcmpi(ext, '.txt')
    matrixDelimiter = 'tab';
    printDelimiter = sprintf('\t');
else
    matrixDelimiter = ',';
    printDelimiter = ',';
end

if exist('writematrix', 'file') == 2
    writematrix(cmap, target, 'Delimiter', matrixDelimiter);
    return
end

fid = fopen(target, 'w');
if fid < 0
    error('ColormapDesigner:FileWriteFailed', 'Could not open the selected file for writing.');
end
cleanupObj = onCleanup(@() fclose(fid));
for k = 1:size(cmap, 1)
    fprintf(fid, ['%.10g' printDelimiter '%.10g' printDelimiter '%.10g\n'], ...
        cmap(k, 1), cmap(k, 2), cmap(k, 3));
end
clear cleanupObj
end

function generateMFunction(fig)
app = getApp(fig);
cmap = app.CurrentCmap;
[fileName, folderName] = uiputfile({'*.m', 'MATLAB function (*.m)'}, ...
    'Generate colormap function', 'my_colormap.m');
if isCanceled(fileName)
    setStatus(app, 'Function export canceled.');
    setApp(app);
    return
end

[~, functionName] = fileparts(fileName);
if ~isvarname(functionName)
    uialert(app.Figure, 'Choose a file name that is also a valid MATLAB function name.', ...
        'Invalid function name');
    setStatus(app, 'Function export canceled: invalid function name.');
    setApp(app);
    return
end

target = fullfile(folderName, fileName);
fid = fopen(target, 'w');
if fid < 0
    uialert(app.Figure, 'Could not open the selected file for writing.', 'Export failed');
    setStatus(app, 'Function export failed.');
    setApp(app);
    return
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'function cmap = %s(n)\n', functionName);
fprintf(fid, '%% %s  Generated by ColormapDesigner.\n', functionName);
fprintf(fid, '%% Usage: cmap = %s(n)\n\n', functionName);
fprintf(fid, 'if nargin < 1 || isempty(n)\n    n = %d;\nend\n', size(cmap, 1));
fprintf(fid, 'n = max(2, round(double(n)));\n');
fprintf(fid, 'base = [ ...\n');
for k = 1:size(cmap, 1)
    fprintf(fid, '    %.10g %.10g %.10g', cmap(k, 1), cmap(k, 2), cmap(k, 3));
    if k < size(cmap, 1)
        fprintf(fid, '; ...\n');
    else
        fprintf(fid, ' ...\n');
    end
end
fprintf(fid, '];\n');
fprintf(fid, 'x = linspace(0, 1, size(base, 1));\n');
fprintf(fid, 'xi = linspace(0, 1, n);\n');
fprintf(fid, 'cmap = interp1(x, base, xi, ''linear'');\n');
fprintf(fid, 'cmap(~isfinite(cmap)) = 0;\n');
fprintf(fid, 'cmap = max(0, min(1, cmap));\n');
fprintf(fid, 'end\n');
clear cleanupObj

setStatus(app, ['Generated function: ' target]);
setApp(app);
end

function copyColormapCode(fig)
app = getApp(fig);
cmapText = matrixToCode(app.CurrentCmap);
code = sprintf('cmap = [ ...\n%s];\ncolormap(cmap);\ncolorbar;\n', cmapText);
try
    clipboard('copy', code);
    setStatus(app, 'Copied colormap code to clipboard.');
catch err
    uialert(app.Figure, err.message, 'Clipboard failed');
    setStatus(app, 'Clipboard copy failed.');
end
setApp(app);
end

function applyToCurrentFigure(fig, reverseMap)
app = getApp(fig);
cmap = app.CurrentCmap;
if reverseMap
    cmap = flipud(cmap);
end

targetFigure = getCurrentExternalFigure(app);
if isempty(targetFigure) || ~isvalid(targetFigure)
    uialert(app.Figure, 'No current external figure is available.', 'Apply colormap');
    setStatus(app, 'Apply failed: no current external figure.');
    setApp(app);
    return
end

colormap(targetFigure, cmap);
setStatus(app, 'Applied colormap to current figure.');
setApp(app);
end

function applyToSelectedAxes(fig, reverseMap)
app = getApp(fig);
cmap = app.CurrentCmap;
if reverseMap
    cmap = flipud(cmap);
end

targetFigure = getCurrentExternalFigure(app);
targetAxes = [];
if ~isempty(targetFigure) && isvalid(targetFigure)
    try
        targetAxes = targetFigure.CurrentAxes;
    catch
        targetAxes = [];
    end
end

if isempty(targetAxes) || ~isvalid(targetAxes)
    uialert(app.Figure, 'No selected external axes is available.', 'Apply colormap');
    setStatus(app, 'Apply failed: no selected external axes.');
    setApp(app);
    return
end

colormap(targetAxes, cmap);
setStatus(app, 'Applied colormap to selected axes.');
setApp(app);
end

function exportPreviewFigure(fig)
app = getApp(fig);
[fileName, folderName] = uiputfile({'*.png', 'PNG image (*.png)'; '*.pdf', 'PDF file (*.pdf)'}, ...
    'Export preview figure', 'colormap_preview.png');
if isCanceled(fileName)
    setStatus(app, 'Preview export canceled.');
    setApp(app);
    return
end

target = fullfile(folderName, fileName);
tmp = figure('Color', 'white', 'Units', 'pixels', 'Position', [100 100 1200 800], ...
    'Visible', 'off');
cleanupObj = onCleanup(@() close(tmp));
layout = tiledlayout(tmp, 4, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

ax = nexttile(layout, [1 2]);
n = size(app.CurrentCmap, 1);
imagesc(ax, linspace(0, 1, n), [0 1], repmat(1:n, 12, 1));
colormap(ax, app.CurrentCmap);
set(ax, 'CLim', [1 n]);
ax.YTick = [];
title(ax, 'Current colormap', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'normalized value', 'FontName', 'Arial');

ax = nexttile(layout);
imagesc(ax, app.PreviewData.Sequential);
axis(ax, 'image');
colormap(ax, app.CurrentCmap);
colorbar(ax);
title(ax, 'sequential data', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = nexttile(layout);
imagesc(ax, app.PreviewData.Diverging);
axis(ax, 'image');
limitValue = max(abs(app.PreviewData.Diverging(:)));
set(ax, 'CLim', [-limitValue limitValue]);
colormap(ax, app.CurrentCmap);
colorbar(ax);
title(ax, 'diverging field', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = nexttile(layout);
lineColors = getPreviewLineColors(app.CurrentCmap, size(app.PreviewData.CategoricalLines, 1));
hold(ax, 'on');
for k = 1:size(app.PreviewData.CategoricalLines, 1)
    plot(ax, app.PreviewData.LineX, app.PreviewData.CategoricalLines(k, :), ...
        'LineWidth', 1.4, 'Color', lineColors(k, :));
end
hold(ax, 'off');
grid(ax, 'on');
title(ax, 'categorical line plot', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = nexttile(layout);
imagesc(ax, app.PreviewData.Time, app.PreviewData.Frequency, app.PreviewData.Spectrum);
axis(ax, 'xy');
colormap(ax, app.CurrentCmap);
colorbar(ax);
title(ax, 'time-frequency texture', 'FontName', 'Arial', 'FontWeight', 'normal');
xlabel(ax, 'time / offset', 'FontName', 'Arial');
ylabel(ax, 'frequency / wavenumber', 'FontName', 'Arial');

ax = nexttile(layout);
imagesc(ax, app.PreviewData.FieldX, app.PreviewData.FieldY, app.PreviewData.SignedField);
axis(ax, 'image');
fieldLimit = max(abs(app.PreviewData.SignedField(:)));
set(ax, 'CLim', [-fieldLimit fieldLimit]);
colormap(ax, app.CurrentCmap);
colorbar(ax);
title(ax, 'positive/negative field', 'FontName', 'Arial', 'FontWeight', 'normal');

ax = nexttile(layout);
grayCmap = rgbToGrayCmap(simulateColorblindPreview(app.CurrentCmap, 'deuteranopia'));
imagesc(ax, app.PreviewData.Sequential);
axis(ax, 'image');
colormap(ax, grayCmap);
colorbar(ax);
title(ax, 'grayscale / colorblind check', 'FontName', 'Arial', 'FontWeight', 'normal');

allAxes = findall(tmp, 'Type', 'axes');
formatAxes(allAxes);

try
    exportgraphics(tmp, target, 'Resolution', 300);
catch
    [~, ~, ext] = fileparts(target);
    if strcmpi(ext, '.pdf')
        print(tmp, target, '-dpdf', '-vector');
    else
        print(tmp, target, '-dpng', '-r300');
    end
end
clear cleanupObj
setStatus(app, ['Exported preview: ' target]);
setApp(app);
end

function onPaletteChanged(fig)
app = getApp(fig);
nodes = loadPaletteColormap(app.PaletteDropDown.Value);
app.NodeTable.Data = nodesToTable(nodes);
setApp(app);
updateColormap(fig, true);
end

function onPaletteFilterChanged(fig)
app = getApp(fig);
currentValue = string(app.PaletteDropDown.Value);
names = getPaletteNames(app.PaletteGroupDropDown.Value, app.SearchEditField.Value);
app.PaletteDropDown.Items = names;
if any(strcmp(names, currentValue))
    app.PaletteDropDown.Value = char(currentValue);
else
    app.PaletteDropDown.Value = names{1};
end
nodes = loadPaletteColormap(app.PaletteDropDown.Value);
app.NodeTable.Data = nodesToTable(nodes);
setStatus(app, sprintf('Filtered palettes: %d match(es).', numel(names)));
setApp(app);
updateColormap(fig, true);
end

function onTableEdited(fig, event)
app = getApp(fig);
data = app.NodeTable.Data;
try
    columnIndex = event.Indices(2);
catch
    columnIndex = [];
end

if istable(data) && ~isempty(columnIndex) && columnIndex ~= 5
    try
        rowIndex = event.Indices(1);
        r = clip01(double(data.R(rowIndex)));
        g = clip01(double(data.G(rowIndex)));
        b = clip01(double(data.B(rowIndex)));
        data.Hex{rowIndex} = rgb2hex([r g b]);
        app.NodeTable.Data = data;
    catch
    end
end

setApp(app);
updateColormap(fig, true);
end

function onTableSelection(fig, event)
app = getApp(fig);
rows = [];
try
    selection = event.Selection;
    if isnumeric(selection)
        rows = unique(selection(:, 1));
    end
catch
end
try
    if isempty(rows) && isnumeric(app.NodeTable.Selection)
        rows = unique(app.NodeTable.Selection(:, 1));
    end
catch
end
app.SelectedRows = rows(:)';
setApp(app);
end

function onSliderChanging(fig, slider, event)
try
    slider.Value = event.Value;
catch
end
updateColormap(fig, false);
end

function addNode(fig)
app = getApp(fig);
cleanTable = sanitizeNodeTable(app.NodeTable.Data);
nodes = tableToNodes(cleanTable);

[~, gapIndex] = max(diff(nodes(:, 1)));
if isempty(gapIndex) || gapIndex < 1
    newPos = 0.5;
    newRgb = mean(nodes(:, 2:4), 1);
else
    newPos = mean(nodes(gapIndex:gapIndex + 1, 1));
    newRgb = mean(nodes(gapIndex:gapIndex + 1, 2:4), 1);
end

nodes = [nodes; newPos newRgb];
app.NodeTable.Data = nodesToTable(sanitizeNodesArray(nodes));
setStatus(app, 'Added a color node.');
setApp(app);
updateColormap(fig, true);
end

function deleteNode(fig)
app = getApp(fig);
cleanTable = sanitizeNodeTable(app.NodeTable.Data);
nodes = tableToNodes(cleanTable);

if size(nodes, 1) <= 2
    uialert(app.Figure, 'At least two color nodes are required.', 'Delete node');
    setStatus(app, 'Delete skipped: at least two nodes are required.');
    setApp(app);
    return
end

rows = app.SelectedRows;
if isempty(rows)
    try
        selection = app.NodeTable.Selection;
        rows = unique(selection(:, 1));
    catch
        rows = [];
    end
end
if isempty(rows)
    rows = size(nodes, 1);
end

rows = rows(rows >= 1 & rows <= size(nodes, 1));
if isempty(rows)
    rows = size(nodes, 1);
end
if numel(rows) >= size(nodes, 1) - 1
    rows = rows(1);
end

nodes(rows, :) = [];
app.SelectedRows = [];
app.NodeTable.Data = nodesToTable(sanitizeNodesArray(nodes));
setStatus(app, 'Deleted selected color node.');
setApp(app);
updateColormap(fig, true);
end

function options = readOptions(app)
options = struct();
options.Length = normalizeLength(str2double(app.LengthDropDown.Value));
options.Interpolation = app.InterpDropDown.Value;
options.Reverse = logical(app.ReverseCheckBox.Value);
options.Gamma = app.GammaSlider.Value;
options.Brightness = app.BrightnessSlider.Value;
options.Contrast = app.ContrastSlider.Value;
options.Saturation = app.SaturationSlider.Value;
options.TruncateStart = app.TruncateStartSlider.Value;
options.TruncateEnd = app.TruncateEndSlider.Value;
options.CenterLock = logical(app.CenterLockCheckBox.Value);
if strcmpi(app.CenterColorDropDown.Value, 'Light gray')
    options.CenterColor = [0.92 0.92 0.90];
else
    options.CenterColor = [1 1 1];
end
end

function updateValueLabels(app)
app.GammaValue.Text = sprintf('%.2f', app.GammaSlider.Value);
app.BrightnessValue.Text = sprintf('%.2f', app.BrightnessSlider.Value);
app.ContrastValue.Text = sprintf('%.2f', app.ContrastSlider.Value);
app.SaturationValue.Text = sprintf('%.2f', app.SaturationSlider.Value);
app.TruncateStartValue.Text = sprintf('%.2f', app.TruncateStartSlider.Value);
app.TruncateEndValue.Text = sprintf('%.2f', app.TruncateEndSlider.Value);
end

function cleanTable = sanitizeNodeTable(rawData)
if istable(rawData)
    rowCount = height(rawData);
    pos = tableColumnToDouble(rawData, 'Position', rowCount, NaN);
    r = tableColumnToDouble(rawData, 'R', rowCount, 0);
    g = tableColumnToDouble(rawData, 'G', rowCount, 0);
    b = tableColumnToDouble(rawData, 'B', rowCount, 0);
    hexValues = tableColumnToString(rawData, 'Hex', rowCount);
elseif isnumeric(rawData)
    nodes = sanitizeNodesArray(rawData);
    cleanTable = nodesToTable(nodes);
    return
else
    cleanTable = nodesToTable([0 0 0 0; 1 1 1 1]);
    return
end

if rowCount == 0
    cleanTable = nodesToTable([0 0 0 0; 1 1 1 1]);
    return
end

if all(~isfinite(pos))
    pos = linspace(0, 1, rowCount)';
else
    badPos = ~isfinite(pos);
    pos(badPos) = linspace(0, 1, nnz(badPos));
end

rgb = [r g b];
rgb(~isfinite(rgb)) = 0;
rgb = clip01(rgb);

for k = 1:rowCount
    [parsedRgb, ok] = tryHex2rgb(hexValues(k));
    if ok
        rgb(k, :) = parsedRgb;
    end
end

nodes = sanitizeNodesArray([clip01(pos(:)) rgb]);
cleanTable = nodesToTable(nodes);
end

function value = tableColumnToDouble(tbl, name, rowCount, defaultValue)
if any(strcmp(tbl.Properties.VariableNames, name))
    raw = tbl.(name);
else
    value = repmat(defaultValue, rowCount, 1);
    return
end

if isnumeric(raw)
    value = double(raw(:));
elseif iscell(raw)
    value = nan(numel(raw), 1);
    for k = 1:numel(raw)
        value(k) = str2double(string(raw{k}));
    end
else
    value = str2double(string(raw(:)));
end

if numel(value) < rowCount
    value(end + 1:rowCount, 1) = defaultValue;
end
value = value(1:rowCount);
end

function values = tableColumnToString(tbl, name, rowCount)
if any(strcmp(tbl.Properties.VariableNames, name))
    raw = tbl.(name);
else
    values = strings(rowCount, 1);
    return
end

if iscell(raw)
    values = strings(numel(raw), 1);
    for k = 1:numel(raw)
        values(k) = string(raw{k});
    end
elseif ischar(raw)
    values = string(cellstr(raw));
else
    values = string(raw(:));
end

if numel(values) < rowCount
    values(end + 1:rowCount, 1) = "";
end
values = values(1:rowCount);
end

function nodes = tableToNodes(tbl)
tbl = sanitizeNodeTable(tbl);
nodes = [tbl.Position tbl.R tbl.G tbl.B];
nodes = sanitizeNodesArray(nodes);
end

function tbl = nodesToTable(nodes)
nodes = sanitizeNodesArray(nodes);
hexValues = cell(size(nodes, 1), 1);
for k = 1:size(nodes, 1)
    hexValues{k} = rgb2hex(nodes(k, 2:4));
end
tbl = table(nodes(:, 1), nodes(:, 2), nodes(:, 3), nodes(:, 4), hexValues, ...
    'VariableNames', {'Position', 'R', 'G', 'B', 'Hex'});
end

function nodes = sanitizeNodesArray(nodes)
if isempty(nodes) || ~isnumeric(nodes) || size(nodes, 2) < 4
    nodes = [0 0 0 0; 1 1 1 1];
else
    nodes = double(nodes(:, 1:4));
end

nodes(~isfinite(nodes)) = 0;
nodes(:, 1) = clip01(nodes(:, 1));
nodes(:, 2:4) = clip01(nodes(:, 2:4));
nodes = sortrows(nodes, 1);

[~, uniqueIndex] = unique(nodes(:, 1), 'stable');
nodes = nodes(uniqueIndex, :);

if size(nodes, 1) == 0
    nodes = [0 0 0 0; 1 1 1 1];
elseif size(nodes, 1) == 1
    rgb = nodes(1, 2:4);
    nodes = [0 rgb; 1 rgb];
end

nodes = sortrows(nodes, 1);
end

function rgb = hex2rgb(hexValue)
[rgb, ok] = tryHex2rgb(hexValue);
if ~ok
    error('ColormapDesigner:InvalidHex', 'Invalid hex color. Use a value like #3B6EA8.');
end
end

function [rgb, ok] = tryHex2rgb(hexValue)
ok = false;
rgb = [0 0 0];

if isstring(hexValue) || ischar(hexValue)
    hexValue = char(strtrim(string(hexValue)));
elseif iscell(hexValue) && ~isempty(hexValue)
    hexValue = char(strtrim(string(hexValue{1})));
else
    return
end

if startsWith(hexValue, '#')
    hexValue = hexValue(2:end);
end
if numel(hexValue) ~= 6 || any(~isstrprop(hexValue, 'xdigit'))
    return
end

rgb = [hex2dec(hexValue(1:2)), hex2dec(hexValue(3:4)), hex2dec(hexValue(5:6))] ./ 255;
ok = true;
end

function hexValue = rgb2hex(rgb)
rgb = clip01(double(rgb(:)'));
if numel(rgb) < 3
    rgb(1, end + 1:3) = 0;
end
rgb = round(rgb(1:3) .* 255);
hexValue = sprintf('#%02X%02X%02X', rgb(1), rgb(2), rgb(3));
end

function clipped = clip01(value)
clipped = min(1, max(0, value));
end

function cmap = cleanCmap(cmap)
cmap = real(cmap);
cmap(~isfinite(cmap)) = 0;
cmap = clip01(cmap);
end

function n = normalizeLength(n)
if isempty(n) || ~isscalar(n) || ~isfinite(n)
    n = 256;
end
n = round(double(n));
n = max(2, min(4096, n));
end

function value = getOption(options, fieldName, defaultValue)
if isstruct(options) && isfield(options, fieldName)
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function cmap = applyCenterLock(cmap, centerColor)
centerColor = clip01(centerColor(:)');
if numel(centerColor) < 3
    centerColor(1, end + 1:3) = 1;
end
centerColor = centerColor(1:3);

n = size(cmap, 1);
t = linspace(0, 1, n)';
width = 0.08;
blend = max(0, 1 - abs(t - 0.5) ./ width);
cmap = cmap .* (1 - 0.75 .* blend) + centerColor .* (0.75 .* blend);
mid = floor((n + 1) / 2);
cmap(mid, :) = centerColor;
if mod(n, 2) == 0
    cmap(mid + 1, :) = centerColor;
end
cmap = cleanCmap(cmap);
end

function nodes = makeNodes(rgb)
rgb = clip01(double(rgb));
nodes = [linspace(0, 1, size(rgb, 1))' rgb];
end

function nodes = cmapToNodes(cmap, nodeCount)
cmap = cleanCmap(cmap);
nodeCount = min(size(cmap, 1), max(2, nodeCount));
idx = unique(round(linspace(1, size(cmap, 1), nodeCount)));
pos = linspace(0, 1, numel(idx))';
nodes = [pos cmap(idx, :)];
end

function cmap = safeBuiltinColormap(name, n)
try
    cmap = feval(name, n);
    cmap = cleanCmap(cmap);
catch
    switch lower(name)
        case 'turbo'
            cmap = interpolateColormap(makeNodes([ ...
                0.189 0.071 0.232
                0.252 0.265 0.530
                0.130 0.560 0.551
                0.369 0.788 0.383
                0.994 0.906 0.144
                0.985 0.535 0.133
                0.714 0.090 0.102]), n, 'pchip RGB');
        case 'parula'
            cmap = parulaFallback(n);
        otherwise
            cmap = jet(n);
    end
end
end

function cmap = parulaFallback(n)
try
    cmap = parula(n);
catch
    nodes = makeNodes([ ...
        0.2081 0.1663 0.5292
        0.1181 0.2783 0.7306
        0.1626 0.4757 0.5581
        0.2461 0.6332 0.3472
        0.6635 0.7801 0.2199
        0.9763 0.9831 0.0538]);
    cmap = interpolateColormap(nodes, n, 'pchip RGB');
end
end

function previewData = makePreviewData()
[x, y, z] = peaks(120);
previewData.X = x;
previewData.Y = y;
previewData.Z = z;

[mx, my] = meshgrid(linspace(-4, 4, 180), linspace(-3, 3, 140));
previewData.Sequential = exp(-0.18 .* (mx.^2 + my.^2)) .* sin(2.4 .* mx) + ...
    0.35 .* cos(3.2 .* my) + 0.12 .* mx;

[dx, dy] = meshgrid(linspace(-2.5, 2.5, 170), linspace(-2.5, 2.5, 170));
previewData.Diverging = 1.3 .* dx .* exp(-0.35 .* (dx.^2 + dy.^2)) + ...
    0.55 .* sin(2.5 .* dx) .* cos(1.6 .* dy);

lineX = linspace(0, 1, 180);
previewData.LineX = lineX;
previewData.CategoricalLines = zeros(8, numel(lineX));
for k = 1:8
    previewData.CategoricalLines(k, :) = 0.25 .* k + ...
        sin(2 * pi * (k * 0.18 + lineX .* (0.6 + 0.08 * k))) + ...
        0.18 .* cos(2 * pi * (lineX .* (1.3 + 0.05 * k)));
end

time = linspace(0, 12, 220);
frequency = linspace(0, 80, 150);
[tt, ff] = meshgrid(time, frequency);
ridge1 = exp(-((ff - (12 + 3.2 .* tt)).^2) ./ 65);
ridge2 = 0.75 .* exp(-((ff - (58 - 2.2 .* tt)).^2) ./ 95);
bands = 0.18 .* sin(0.8 .* tt + 0.18 .* ff) + 0.10 .* cos(1.7 .* tt - 0.11 .* ff);
previewData.Spectrum = ridge1 + ridge2 + bands;
previewData.Time = time;
previewData.Frequency = frequency;

fieldX = linspace(-0.8, 0.8, 180);
fieldY = linspace(-0.8, 0.8, 160);
[fx, fy] = meshgrid(fieldX, fieldY);
previewData.FieldX = fieldX;
previewData.FieldY = fieldY;
previewData.SignedField = sin(8 .* fx) .* exp(-4 .* (fx.^2 + fy.^2)) - ...
    0.75 .* cos(7 .* fy) .* exp(-5 .* ((fx + 0.18).^2 + (fy - 0.12).^2));
end

function app = getApp(fig)
app = getappdata(fig, 'ColormapDesignerApp');
end

function setApp(app)
if isfield(app, 'Figure') && isvalid(app.Figure)
    setappdata(app.Figure, 'ColormapDesignerApp', app);
end
end

function setStatus(app, message)
if isfield(app, 'StatusLabel') && isvalid(app.StatusLabel)
    app.StatusLabel.Text = message;
end
end

function formatAxes(axesList)
for k = 1:numel(axesList)
    ax = axesList(k);
    if isvalid(ax)
        ax.FontName = 'Arial';
        ax.FontSize = 11;
        ax.LineWidth = 0.8;
        ax.Box = 'on';
        ax.Color = 'white';
    end
end
end

function tf = isCanceled(fileName)
tf = isequal(fileName, 0);
end

function fig = getCurrentExternalFigure(app)
fig = [];
try
    currentFigure = get(groot, 'CurrentFigure');
catch
    currentFigure = [];
end

if ~isempty(currentFigure) && isvalid(currentFigure) && currentFigure ~= app.Figure
    fig = currentFigure;
    return
end

figures = findall(groot, 'Type', 'figure');
for k = 1:numel(figures)
    if isvalid(figures(k)) && figures(k) ~= app.Figure
        fig = figures(k);
        return
    end
end
end

function textValue = matrixToCode(cmap)
lines = strings(size(cmap, 1), 1);
for k = 1:size(cmap, 1)
    if k < size(cmap, 1)
        lines(k) = sprintf('    %.10g %.10g %.10g; ...', cmap(k, 1), cmap(k, 2), cmap(k, 3));
    else
        lines(k) = sprintf('    %.10g %.10g %.10g ...', cmap(k, 1), cmap(k, 2), cmap(k, 3));
    end
end
textValue = strjoin(lines, newline);
textValue = char(textValue + newline);
end

