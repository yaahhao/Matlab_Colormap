%% Demo_ColorKitFull
% End-to-end script demo for the ColorKit MATLAB colormap toolkit.
%
% Author: zhaoyh, 2026.
% Email: zhao2025@mail.sustech.edu.cn
%
% This file is intentionally written as a script, not a function. Open the
% project folder in MATLAB, run addpath(genpath(pwd)), then press Run or
% execute the cells section by section. The demo introduces the main
% workflows and exports the figures used by the README.
%
% Main ColorKit actions used here:
%   ColorKit              main toolbox entry
%   'palette'            read a named palette or catalog ID
%   'ramp'               convenience alias for palette(name,'nColors',N)
%   'pick'               pick colors from image pixels
%   'imagebar'           sample and reconstruct a colorbar from an image
%   'theme-grid'         extract dominant colors by quantized statistics
%   'theme-cluster'      extract dominant colors by clustering/fallback
%   'add-preset'         save any existing N-by-3 colormap as a user preset
%   'set-use'            update your personal recommended-use note
%   'cards'              browse palettes as color cards
%   'catalog'            return the palette catalog table
%   'about'              summarize palette-group counts
%
% Main options:
%   'nColors', N         return exactly N colors. Use 256 for continuous
%                        colormaps, 8-12 for discrete/classed maps.
%   'samples', N         sample N equally spaced anchor colors between two
%                        image colorbar endpoints.
%   'preview', true      show a palette preview window.
%   'points', [x y; ...] use fixed image-pixel coordinates for reproducible
%                        image color picking.
%   'endpoints', [x1 y1; x2 y2]
%                        first and last points of a colorbar in an image.
%   'columns', 4         number of columns in the palette-card browser.
%   'visible', true      show the card browser window.
%   'saveAs', file       export palette cards to an image/PDF file.
%   'presetName', name   user palette name for 'add-preset'.
%   'paletteGroup', name palette group for user-added palettes. Default
%                        "none" maps to "Custom".
%   'type', value        optional palette type metadata.
%   'sourceStyle', text  optional style or provenance note.

clearvars;
close all;
clc;

toolboxDir =pwd;
addpath(toolboxDir);

% This demo is intentionally interactive. It imports real images in sections
% 5 and 6 so the example matches normal use.
showPreview = true;

% Demo figures are exported for the README.
exportFigures = true;
outputFolder = fullfile(toolboxDir, 'Figures');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Plot palette names. Change these values only; calls and titles update
% automatically below.
mapGroup = "Set10";
mapSurface = "Viridis";
mapLine = "Line8";
mapDiverging = "BlueWhiteRed";
mapSpectrum = "BlueYellow";
mapDiscrete = "Colorblind12";
nContinuous = 256;
nDiscrete = 9;

fprintf('\n=== ColorKit full demo ===\n');
fprintf('Toolbox folder: %s\n\n', toolboxDir);

%% 1. What is inside the toolbox?
% ColorKit now exposes a curated named library with no more than 300
% palettes. The main browser uses neutral groups such as Sequential,
% Diverging, Categorical, Cyclic, Grayscale, and Custom. Palettes are
% stored as HEX anchors, then interpolated to the requested number of
% colors.

aboutTable = ColorKit('about');
catalogTable = ColorKit('catalog');

disp('Built-in palette summary:');
disp(aboutTable);
fprintf('Full catalog rows: %d\n\n', height(catalogTable));
disp('First 12 catalog entries:');
disp(catalogTable(1:12, :));

%% 2. Browse color cards before choosing a palette.
% The card browser is meant to feel like a printed cheatsheet.
%
% Syntax:
%   ColorKit('cards', paletteGroupOrKeyword, startIndex, endIndex, options...)
%
% paletteGroupOrKeyword:
%   'All' shows the complete curated catalog.
%   A palette group such as 'Sequential' or 'Diverging' filters by group.
%   A keyword such as 'blue' or 'orange' searches metadata.
%
% startIndex/endIndex:
%   Range inside the filtered catalog to browse.
%
% Useful options:
%   'nColors', 256  show every selected ID as a 256-color strip.
%   'columns', 4    layout columns.
%   'visible', true show the figure.
%   'saveAs', file  export the browser figure.

figCardsNative = ColorKit('cards', 'All', 1, 120, ...
    'columns', 4, 'visible', showPreview);

figCardsDense = ColorKit('cards', 'Sequential', 1, 40, ...
    'nColors', 256, 'columns', 4, 'visible', showPreview);

figCardsRamp = ColorKit('cards', 'Diverging', 1, 40, ...
    'nColors', 256, 'columns', 4, 'visible', showPreview);

exportgraphics(figCardsNative, fullfile(outputFolder, 'cards_all.png'), 'Resolution', 220);
exportgraphics(figCardsDense, fullfile(outputFolder, 'cards_sequential_256.png'), 'Resolution', 220);
exportgraphics(figCardsRamp, fullfile(outputFolder, 'cards_diverging_256.png'), 'Resolution', 220);

%% 3. Basic palette calls.
% 'palette' returns a named preset. Use 'nColors' for continuous maps and
% categorical expansion.

C_group = ColorKit('palette', mapGroup, 'nColors', 10, 'preview', showPreview);

% Add 'nColors' when you need a smooth colormap:
C_surface = ColorKit('palette', mapSurface, 'nColors', nContinuous, 'preview', false);

% Categorical palettes are useful for multiple line series.
C_line = ColorKit('palette', mapLine, 'nColors', 8, 'preview', false);

% For discrete/classed heatmaps, request fewer colors.
C_discrete = ColorKit('palette', mapDiscrete, 'nColors', nDiscrete, 'preview', false);

%% 4. Scientific plotting examples.
% This section shows how the returned N-by-3 RGB matrices are used in
% common MATLAB plots.

figScientific = figure('Name', 'ColorKit scientific plotting examples', ...
    'NumberTitle', 'off', 'Color', 'white', 'Visible', visibilityText(showPreview), ...
    'Position', [80 80 1380 860]);
layout = tiledlayout(figScientific, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, 'ColorKit: named publication-style palettes for MATLAB plots', ...
    'FontName', 'Arial', 'FontWeight', 'bold');

ax = nexttile(layout);
[x, y, z] = peaks(140);
surf(ax, x, y, z, 'EdgeColor', 'none', 'FaceColor', 'interp');
view(ax, 38, 28);
axis(ax, 'tight');
colormap(ax, C_surface);
colorbar(ax);
title(ax, sprintf("surf: %s, %d colors", mapSurface, nContinuous), 'Interpreter', 'none');
xlabel(ax, 'x'); ylabel(ax, 'y'); zlabel(ax, 'z');

ax = nexttile(layout);
xLine = linspace(0, 10, 260);
hold(ax, 'on');
for k = 1:size(C_line, 1)
    yLine = sin(0.72 .* xLine + 0.42 .* k);
    plot(ax, xLine, yLine, 'Color', C_line(k, :), 'LineWidth', 1.45);
end
grid(ax, 'on');
axis(ax, 'tight');
title(ax, sprintf("line plot: %s, %d colors", mapLine, size(C_line, 1)), 'Interpreter', 'none');
xlabel(ax, 'x'); ylabel(ax, 'response');

ax = nexttile(layout);
C_diverging = ColorKit('palette', mapDiverging, 'nColors', nContinuous, 'preview', false);
[dx, dy] = meshgrid(linspace(-2.6, 2.6, 190), linspace(-2.6, 2.6, 190));
dz = 1.2 .* dx .* exp(-0.35 .* (dx .^ 2 + dy .^ 2)) + ...
    0.50 .* sin(2.2 .* dx) .* cos(1.8 .* dy);
contourf(ax, dx, dy, dz, 28, 'LineColor', 'none');
axis(ax, 'image');
limitValue = max(abs(dz(:)));
set(ax, 'CLim', [-limitValue limitValue]);
colormap(ax, C_diverging);
colorbar(ax);
title(ax, sprintf("contourf: %s", mapDiverging), 'Interpreter', 'none');
xlabel(ax, 'x'); ylabel(ax, 'y');

ax = nexttile(layout);
C_spectrum = ColorKit('palette', mapSpectrum, 'nColors', nContinuous, 'preview', false);
t = linspace(0, 12, 260);
f = linspace(0, 80, 190);
[tt, ff] = meshgrid(t, f);
ridge1 = exp(-((ff - (10 + 3.4 .* tt)) .^ 2) ./ 65);
ridge2 = 0.78 .* exp(-((ff - (62 - 2.5 .* tt)) .^ 2) ./ 105);
texture = 0.20 .* sin(0.75 .* tt + 0.18 .* ff) + 0.10 .* cos(1.5 .* tt - 0.10 .* ff);
imagesc(ax, t, f, ridge1 + ridge2 + texture);
axis(ax, 'xy');
colormap(ax, C_spectrum);
colorbar(ax);
title(ax, sprintf("imagesc: %s", mapSpectrum), 'Interpreter', 'none');
xlabel(ax, 'x'); ylabel(ax, 'y');

ax = nexttile(layout);
rng(6, 'twister');
centers = [-2 -1; -0.5 1.2; 1.4 -0.8; 2.1 1.0];
pointsPerGroup = 72;
sx = zeros(pointsPerGroup * size(centers, 1), 1);
sy = sx;
groupIndex = sx;
for k = 1:size(centers, 1)
    idx = (1:pointsPerGroup) + (k - 1) * pointsPerGroup;
    xy = centers(k, :) + 0.38 .* randn(pointsPerGroup, 2);
    sx(idx) = xy(:, 1);
    sy(idx) = xy(:, 2);
    groupIndex(idx) = k;
end
scatter(ax, sx, sy, 34, C_group(groupIndex, :), 'filled', ...
    'MarkerFaceAlpha', 0.78, 'MarkerEdgeColor', [0.15 0.15 0.15], ...
    'MarkerEdgeAlpha', 0.25);
axis(ax, 'equal'); grid(ax, 'on');
title(ax, sprintf("grouped scatter: %s", mapGroup), 'Interpreter', 'none');
xlabel(ax, 'feature 1'); ylabel(ax, 'feature 2');

ax = nexttile(layout);
[hx, hy] = meshgrid(1:24, 1:15);
hz = round(4.5 + 2.8 .* sin(hx ./ 2.6) + 1.7 .* cos(hy ./ 1.8));
hz = max(1, min(size(C_discrete, 1), hz));
imagesc(ax, hz);
axis(ax, 'image');
colormap(ax, C_discrete);
cb = colorbar(ax);
cb.Ticks = 1:size(C_discrete, 1);
title(ax, sprintf("classed heatmap: %s, %d colors", mapDiscrete, nDiscrete), 'Interpreter', 'none');
xlabel(ax, 'column'); ylabel(ax, 'row');

formatAllAxes(figScientific);

exportgraphics(figScientific, fullfile(outputFolder, 'demo_scientific_plots.png'), 'Resolution', 220);

%% 5. Import an image, pick colors, and interpolate them into a ramp.
% Select any real image. Click several colors in the opened figure, then
% press Enter. At least two picked colors are needed to build a gradient.

fprintf('\nSelect an image for color picking.\n');
[pickFile, pickFolder] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', 'Image files'; '*.*', 'All files'}, ...
    'Import an image for color picking', ...
    fullfile(outputFolder, 'fig1_color_pick_source.png'));
if isequal(pickFile, 0)
    error('Demo_ColorKitFull:NoImage', 'No image selected for color picking.');
end

importedImage = imread(fullfile(pickFolder, pickFile));
[C_picked, pickInfo] = ColorKit('pick', importedImage, 'preview', true);
if size(C_picked, 1) < 2
    error('Demo_ColorKitFull:TooFewPickedColors', ...
        'Pick at least two colors, then press Enter.');
end
C_pickedDense = interpolateRgbRamp(C_picked, nContinuous);
figPicked1 = showImagePickProcess(importedImage, pickInfo.Points, C_picked, C_pickedDense);
exportgraphics(figPicked1, fullfile(outputFolder, 'image_pick_colors.png'), 'Resolution', 220);

% Optional: after you like the generated C_pickedDense, save it as a user
% preset. This writes ColorKit_UserPresets.m only when you answer yes.

% row = ColorKit('add-preset', C_picked, ...
%     'presetName', 'My_Color_1', ...
%     'paletteGroup', 'Custom', ...
%     'type', 'none', ...
%     'recommendedUse', 'plot_line', ...
%     'sourceStyle', 'none');
% disp(row);

%% 6. Import an image and sample a colorbar line.
% Select a real figure screenshot that contains a colorbar. Click the first
% and last points of the colorbar. The toolbox then generates N equally
% spaced sampling points along that line. Those anchors are interpolated
% into a dense colormap.

colorbarSampleCount = 16;

fprintf('\nSelect an image that contains a colorbar.\n');
[barFile, barFolder] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', 'Image files'; '*.*', 'All files'}, ...
    'Import an image that contains a colorbar', ...
    fullfile(outputFolder, 'fig2_colorbar_source.png'));
if isequal(barFile, 0)
    error('Demo_ColorKitFull:NoColorbarImage', 'No image selected for colorbar sampling.');
end

barImage = imread(fullfile(barFolder, barFile));

[C_barAnchors, barInfo] = ColorKit('imagebar', barImage, ...
    'samples', colorbarSampleCount, ...
    'preview', true);
barEndpoints = barInfo.Endpoints;
if isempty(barEndpoints) || size(barEndpoints, 1) < 2
    error('Demo_ColorKitFull:TooFewColorbarPoints', ...
        'Two colorbar endpoints are required.');
end

C_bar256 = ColorKit('imagebar', barImage, ...
    'samples', colorbarSampleCount, ...
    'endpoints', barEndpoints, ...
    'nColors', nContinuous, 'preview', true);
figBarProcess = showColorbarSamplingProcess(barImage, barEndpoints, colorbarSampleCount, ...
    C_barAnchors, C_bar256);
exportgraphics(figBarProcess, fullfile(outputFolder, 'image_colorbar_sampling_process.png'), 'Resolution', 220);
% row = ColorKit('add-preset', C_bar256, ...
%     'presetName', 'My_Color_3', ...
%     'paletteGroup', 'Custom', ...
%     'type', 'none', ...
%     'recommendedUse', 'FJ_Spectrum', ...
%     'sourceStyle', 'none');
% disp(row);

%% 7. Image theme extraction.
% theme-grid:
%   Quantizes colors and ranks dominant colors. Fast and deterministic.
%
% theme-cluster:
%   Uses k-means when available, otherwise internal fallback clustering.
%
% This section reuses the image imported in section 5.

C_themeGrid = ColorKit('theme-grid', 8, importedImage, 'preview', showPreview);
C_themeCluster = ColorKit('theme-cluster', 8, importedImage, 'preview', showPreview);

figThemeGrid = showThemeExtractionFigure(importedImage, C_themeGrid, ...
    'Image theme colors: grid quantization');
figThemeCluster = showThemeExtractionFigure(importedImage, C_themeCluster, ...
    'Image theme colors: clustering');
exportgraphics(figThemeGrid, fullfile(outputFolder, 'theme_grid_colors.png'), 'Resolution', 220);
exportgraphics(figThemeCluster, fullfile(outputFolder, 'theme_cluster_colors.png'), 'Resolution', 220);

%% 8. Apply an extracted or selected colormap to your own axes.
figApply = figure('Name', 'Apply ColorKit output to one axes', ...
    'NumberTitle', 'off', 'Color', 'white', 'Visible', visibilityText(showPreview), ...
    'Position', [120 120 680 520]);
ax = axes('Parent', figApply);
imagesc(ax, membrane(1, 80));
axis(ax, 'image');
colormap(ax, C_bar256);
colorbar(ax);
title(ax, 'Applied imagebar-extracted colormap to an axes');
formatAllAxes(figApply);

exportgraphics(figApply, fullfile(outputFolder, 'demo_apply_axes.png'), 'Resolution', 220);

%% 9. Continue editing manually in the GUI.
% For hand tuning, open:
%
%   ColormapDesigner
%
% The GUI is useful for gamma, brightness, contrast, saturation, truncation,
% and diverging-center locking.

fprintf('\nDemo complete.\n');
fprintf('Important variables now in workspace:\n');
fprintf('  aboutTable, catalogTable\n');
fprintf('  C_surface, C_line, C_diverging, C_spectrum\n');
fprintf('  C_group, C_discrete, C_picked, C_pickedDense\n');
fprintf('  C_barAnchors, C_bar256, C_themeGrid, C_themeCluster\n');

%% Local helper functions for this script.

function textValue = visibilityText(showPreview)
if showPreview
    textValue = 'on';
else
    textValue = 'off';
end
end

function cmap = interpolateRgbRamp(anchorColors, nColors)
anchorColors = max(0, min(1, double(anchorColors)));
if size(anchorColors, 1) < 2
    error('Demo_ColorKitFull:TooFewAnchors', ...
        'At least two RGB rows are required to build a ramp.');
end
xAnchor = linspace(0, 1, size(anchorColors, 1));
xQuery = linspace(0, 1, nColors);
cmap = interp1(xAnchor, anchorColors, xQuery, 'pchip');
cmap = max(0, min(1, cmap));
end

function fig = showImagePickProcess(img, points, anchorColors, denseColors)
fig = figure('Name', 'Image color picking workflow', ...
    'Color', 'white', 'Position', [120 120 980 720]);
layout = tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, 'Image color picking: clicked pixels -> anchors -> dense ramp', ...
    'FontName', 'Arial', 'FontWeight', 'bold');

ax = nexttile(layout);
image(ax, img);
axis(ax, 'image');
axis(ax, 'off');
hold(ax, 'on');
plot(ax, points(:, 1), points(:, 2), 'wo', ...
    'MarkerSize', 10, 'LineWidth', 1.8);
plot(ax, points(:, 1), points(:, 2), 'o', ...
    'Color', [0.85 0.05 0.08], 'MarkerSize', 8, 'LineWidth', 1.8);
for k = 1:size(points, 1)
    text(ax, points(k, 1), points(k, 2), sprintf(' %d', k), ...
        'Color', 'white', 'FontName', 'Arial', 'FontWeight', 'bold', ...
        'VerticalAlignment', 'bottom');
end
title(ax, sprintf('Clicked pixels: %d points', size(points, 1)), ...
    'FontName', 'Arial');

ax = nexttile(layout);
showThemeSwatches(ax, anchorColors);
title(ax, sprintf('Picked anchors: %d colors', size(anchorColors, 1)), ...
    'FontName', 'Arial');

ax = nexttile(layout);
image(ax, reshape(denseColors, 1, size(denseColors, 1), 3));
axis(ax, 'tight');
set(ax, 'YTick', [], 'XTick', []);
title(ax, sprintf('Interpolated ramp: %d colors', size(denseColors, 1)), ...
    'FontName', 'Arial');
end

function fig = showColorbarSamplingProcess(img, endpoints, sampleCount, anchorColors, denseColors)
sampleXY = equallySpacedLinePoints(endpoints, sampleCount);
fig = figure('Name', 'Colorbar sampling and interpolation', ...
    'Color', 'white', 'Position', [120 120 1080 620]);
layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, 'Colorbar extraction: endpoints -> equally spaced anchors -> dense ramp', ...
    'FontName', 'Arial', 'FontWeight', 'bold');

ax = nexttile(layout, [2 1]);
image(ax, img);
axis(ax, 'image');
axis(ax, 'off');
hold(ax, 'on');
plot(ax, endpoints(:, 1), endpoints(:, 2), 'w-', 'LineWidth', 3);
plot(ax, endpoints(:, 1), endpoints(:, 2), 'r-', 'LineWidth', 1.4);
plot(ax, sampleXY(:, 1), sampleXY(:, 2), 'wo', ...
    'MarkerFaceColor', [0.05 0.30 0.95], 'MarkerSize', 5);
title(ax, sprintf('%d equally spaced sample points', sampleCount), 'FontName', 'Arial');

ax = nexttile(layout);
image(ax, reshape(anchorColors, 1, size(anchorColors, 1), 3));
axis(ax, 'tight');
set(ax, 'YTick', [], 'XTick', []);
title(ax, sprintf('Sampled anchors: %d colors', size(anchorColors, 1)), ...
    'FontName', 'Arial');

ax = nexttile(layout);
image(ax, reshape(denseColors, 1, size(denseColors, 1), 3));
axis(ax, 'tight');
set(ax, 'YTick', [], 'XTick', []);
title(ax, sprintf('Interpolated ramp: %d colors', size(denseColors, 1)), ...
    'FontName', 'Arial');
end

function points = equallySpacedLinePoints(endpoints, sampleCount)
points = [linspace(endpoints(1, 1), endpoints(2, 1), sampleCount).', ...
    linspace(endpoints(1, 2), endpoints(2, 2), sampleCount).'];
end

function fig = showThemeExtractionFigure(img, colors, titleText)
fig = figure('Name', titleText, 'Color', 'white', 'Position', [120 120 980 720]);
layout = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(layout, titleText, 'Interpreter', 'none', 'FontName', 'Arial', 'FontWeight', 'bold');

ax = nexttile(layout);
image(ax, img);
axis(ax, 'image');
axis(ax, 'off');

ax = nexttile(layout);
showThemeSwatches(ax, colors);
end

function showThemeSwatches(ax, colors)
colors = max(0, min(1, double(colors)));
n = size(colors, 1);
image(ax, reshape(colors, 1, n, 3));
axis(ax, 'tight');
set(ax, 'YTick', [], 'XTick', []);
for k = 1:n
    textColor = [0 0 0];
    if dot(colors(k, :), [0.299 0.587 0.114]) < 0.48
        textColor = [1 1 1];
    end
    text(ax, k, 1, rgbToHexLocal(colors(k, :)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'Rotation', 90, ...
        'FontName', 'Arial', ...
        'FontSize', 10, ...
        'Color', textColor);
end
end

function hex = rgbToHexLocal(rgb)
rgb = round(max(0, min(1, rgb(:).')) * 255);
hex = sprintf('#%02X%02X%02X', rgb(1), rgb(2), rgb(3));
end

function formatAllAxes(fig)
axesList = findall(fig, 'Type', 'axes');
for ii = 1:numel(axesList)
    ax = axesList(ii);
    ax.FontName = 'Arial';
    ax.FontSize = 10.5;
    ax.LineWidth = 0.8;
    ax.Box = 'on';
    ax.Color = 'white';
end
end

