function combined_plot = combine_figures(savename)
figs = findall(0, 'Type', 'figure');
newFig = figure; ... ('Visibility','off');

% Collect all axes from all figures
axesList = [];
for i = 1:length(figs)
    ax = findall(figs(i), 'Type', 'axes');
    ax = ax(arrayfun(@(a) isempty(get(a, 'Tag')), ax)); % exclude legends, etc.
    axesList = [axesList; flipud(ax)]; % flip to keep subplot order
end

n = length(axesList);
rows = ceil(sqrt(n));
cols = ceil(n / rows);

for i = 1:n
    subplot(rows, cols, i, 'Parent', newFig);
    copyobj(allchild(axesList(i)), gca);
    set(gca, 'XLim', get(axesList(i), 'XLim'), ...
             'YLim', get(axesList(i), 'YLim'));
    title(get(get(axesList(i), 'Title'), 'String'));
end


print(newFig, savename, '-dpdf');
end

