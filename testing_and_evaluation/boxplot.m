function h = boxplot(x, varargin)
% BOXPLOT Custom boxplot fallback for machines without the Statistics Toolbox.
% Draws a basic box plot using standard MATLAB plotting functions.

hold_state = ishold;
hold on;

numGroups = size(x, 2);
for g = 1:numGroups
    data = sort(x(:, g));
    data(isnan(data)) = []; % Remove NaNs
    n = length(data);
    if n == 0
        continue;
    end
    
    % Percentile estimation
    q1 = data(max(1, round(0.25 * n)));
    q2 = median(data);
    q3 = data(max(1, round(0.75 * n)));
    
    % IQR and Whiskers (1.5 IQR rule)
    iqr_val = q3 - q1;
    w_min = max(min(data), q1 - 1.5 * iqr_val);
    w_max = min(max(data), q3 + 1.5 * iqr_val);
    
    % Plot styling parameters
    width = 0.4;
    
    % Draw box (rectangle)
    rectangle('Position', [g - width/2, q1, width, q3 - q1], 'EdgeColor', 'b', 'LineWidth', 1.5);
    
    % Draw median line (red)
    line([g - width/2, g + width/2], [q2, q2], 'Color', 'r', 'LineWidth', 2);
    
    % Draw whiskers
    line([g, g], [q3, w_max], 'Color', 'b', 'LineStyle', '--');
    line([g, g], [q1, w_min], 'Color', 'b', 'LineStyle', '--');
    line([g - width/4, g + width/4], [w_max, w_max], 'Color', 'b');
    line([g - width/4, g + width/4], [w_min, w_min], 'Color', 'b');
    
    % Draw outliers
    outliers = data(data < w_min | data > w_max);
    if ~isempty(outliers)
        plot(repmat(g, size(outliers)), outliers, 'ro', 'MarkerSize', 5);
    end
end

% Parse and apply Labels if present in varargin
labels = {};
for idx = 1:2:length(varargin)
    if strcmpi(varargin{idx}, 'Labels')
        labels = varargin{idx+1};
        break;
    end
end

set(gca, 'XTick', 1:numGroups);
if ~isempty(labels)
    set(gca, 'XTickLabel', labels);
end

if ~hold_state
    hold off;
end

h = gca;

end
