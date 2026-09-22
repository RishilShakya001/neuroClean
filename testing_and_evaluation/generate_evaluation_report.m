% In generate_evaluation_report.m

% TEST STEP 3 OF 3: Results Visualization & Statistical Analysis
% This script loads computed metrics and generates comprehensive visualizations, performs statistical significance testing, and produces a final evaluation report.

% Inputs:  plotting_data.mat in TEST-RESULTS-FINAL from previous step
% Outputs: Plots (PNG files), statistical analysis, final_evaluation_log.txt in TEST-RESULTS-FINAL
% This is the final step in the evaluation pipeline.

clc; clear; close all;
fprintf('=== Visualization Script ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% ====== CONFIGURATION ======
results_folder = 'TEST-RESULTS-FINAL';
data_file_name = fullfile(results_folder, 'plotting_data.mat');

common_diary_file = fullfile(results_folder, 'final_evaluation_log.txt');
diary(common_diary_file); % The same file path as the first script
diary on;                 % Resume logging (appends to the existing file)

%% ====== LOAD DATA (CRITICAL) ======
if exist(data_file_name, 'file')
    fprintf('Loading data from: %s\n', data_file_name);
    % Loads: results, stratified_results, avg_SNR_improvement, avg_STOI_improvement, etc.
    load(data_file_name); 
else
    error('Data file not found! Please run "evaluation_pipeline_data_only.m" first.');
end

% --- Determine successful evaluations count (needed for later steps) ---
successful_evals = length(results.SNR_input);
if successful_evals == 0
    fprintf('\nWARNING: No successful evaluations found in data file. Skipping statistical analysis.\n');
    % Create dummy variables to prevent errors in later steps
    p_snr = 1; h_snr = 0; ci_snr = [NaN, NaN]; stats_snr.tstat = NaN; stats_snr.df = 0; cohens_d_snr = 0;
    p_stoi = 1; h_stoi = 0; ci_stoi = [NaN, NaN]; stats_stoi.tstat = NaN; stats_stoi.df = 0; cohens_d_stoi = 0;
else
    % Calculation of the necessary variables for later steps
    n_samples = successful_evals;
    
    % --- Calculation for Statistical Significance ---
    [h_snr, p_snr, ci_snr, stats_snr] = ttest(results.SNR_output, results.SNR_input);
    pooled_std_snr = sqrt(((n_samples-1)*var(results.SNR_input) + (n_samples-1)*var(results.SNR_output)) / (2*n_samples - 2));
    cohens_d_snr = (avg_SNR_output - avg_SNR_input) / pooled_std_snr;
    
    stoi_valid_idx = ~isnan(results.STOI_input) & ~isnan(results.STOI_output);
    stoi_input_valid = results.STOI_input(stoi_valid_idx);
    stoi_output_valid = results.STOI_output(stoi_valid_idx);
    n_stoi_samples = length(stoi_input_valid);
    
    if n_stoi_samples >= 2
        [h_stoi, p_stoi, ci_stoi, stats_stoi] = ttest(stoi_output_valid, stoi_input_valid);
        pooled_std_stoi = sqrt(((n_stoi_samples-1)*var(stoi_input_valid) + (n_stoi_samples-1)*var(stoi_output_valid)) / (2*n_stoi_samples - 2));
        cohens_d_stoi = (mean(stoi_output_valid) - mean(stoi_input_valid)) / pooled_std_stoi;
    else
        p_stoi = NaN; h_stoi = 0; ci_stoi = [NaN, NaN]; stats_stoi.tstat = NaN; stats_stoi.df = 0; cohens_d_stoi = 0;
    end
    
    % --- Calculation for Practical Significance ---
    num_improved_snr = sum(results.SNR_improvement > 0);
    num_improved_stoi = sum(results.STOI_improvement > 0);
    pct_improved_snr = (num_improved_snr / n_samples) * 100;
    pct_improved_stoi = (num_improved_stoi / n_samples) * 100;
    
    JND_SNR = 3.0; JND_STOI = 0.05;
    num_above_jnd_snr = sum(results.SNR_improvement > JND_SNR);
    num_above_jnd_stoi = sum(results.STOI_improvement > JND_STOI);
    pct_above_jnd_snr = (num_above_jnd_snr / n_samples) * 100;
    pct_above_jnd_stoi = (num_above_jnd_stoi / n_samples) * 100;
end

%% ====== STEP 5: GENERATE VISUALIZATIONS ======

fprintf('\n========================================\n');
fprintf('STEP 5: GENERATING VISUALIZATIONS\n');
fprintf('========================================\n');

% Set default figure properties for consistent styling
set(0, 'DefaultAxesFontSize', 11);
set(0, 'DefaultAxesFontName', 'Arial');
set(0, 'DefaultLineLineWidth', 1.5);

% Define color scheme
color_input = [0.8500 0.3250 0.0980];  % Orange
color_output = [0 0.4470 0.7410];      % Blue
color_improvement = [0.4660 0.6740 0.1880];  % Green

%% Figure 1: Distribution Comparison (Box Plots) - IMPROVED
fprintf('Creating Figure 1: Distribution Comparison...\n');
fig1 = figure('Position', [100, 100, 1200, 550], 'Color', 'k');

subplot(1, 2, 1);
h_box1 = boxplot([results.SNR_input', results.SNR_output'], ...
    'Labels', {'Input', 'Output'}, 'Colors', [color_input; color_output], ...
    'Symbol', 'o', 'Widths', 0.5, 'LabelOrientation', 'inline');
set(h_box1, 'LineWidth', 1.5);
set(gca, 'FontSize', 13);  % Larger axis font
ylabel('SNR (dB)', 'FontSize', 14, 'FontWeight', 'bold');
title('SNR Distribution', 'FontSize', 15, 'FontWeight', 'bold');
grid on; box on;
% Add mean markers
hold on;
plot(1, avg_SNR_input, 'x', 'MarkerSize', 14, 'LineWidth', 3.5, 'Color', color_input);
plot(2, avg_SNR_output, 'x', 'MarkerSize', 14, 'LineWidth', 3.5, 'Color', color_output);
legend({'Mean'}, 'Location', 'best', 'FontSize', 12);
hold off;

subplot(1, 2, 2);
h_box2 = boxplot([results.STOI_input', results.STOI_output'], ...
    'Labels', {'Input', 'Output'}, 'Colors', [color_input; color_output], ...
    'Symbol', 'o', 'Widths', 0.5, 'LabelOrientation', 'inline');
set(h_box2, 'LineWidth', 1.5);
set(gca, 'FontSize', 13);  % Larger axis font
ylabel('STOI Score', 'FontSize', 14, 'FontWeight', 'bold');
title('STOI Distribution', 'FontSize', 15, 'FontWeight', 'bold');
stoi_min = min([results.STOI_input, results.STOI_output]);
stoi_max = max([results.STOI_input, results.STOI_output]);
stoi_range = stoi_max - stoi_min;
if ~isnan(stoi_min) && ~isnan(stoi_max) && stoi_range > 0
    ylim([max(0, stoi_min - 0.1*stoi_range), min(1, stoi_max + 0.1*stoi_range)]);
end
grid on; box on;
% Add mean markers
hold on;
if ~isnan(avg_STOI_input)
    plot(1, avg_STOI_input, 'x', 'MarkerSize', 14, 'LineWidth', 3.5, 'Color', color_input);
end
if ~isnan(avg_STOI_output)
    plot(2, avg_STOI_output, 'x', 'MarkerSize', 14, 'LineWidth', 3.5, 'Color', color_output);
end
hold off;

% Tight layout
subplotHandles = findall(gcf, 'Type', 'Axes');
for ax = subplotHandles'
    outerpos = ax.OuterPosition;
    outerpos(2) = outerpos(2) - 0.05;   % shift down
    ax.OuterPosition = outerpos;
end
sgtitle('Performance Distribution Comparison', 'FontSize', 17, 'FontWeight', 'bold');
saveas(fig1, fullfile(results_folder, 'distribution_comparison.png'));
fprintf('  ✓ Saved: distribution_comparison.png\n');

%% Figure 2: Stratified Analysis - IMPROVED
if ~isempty(stratified_results.bin_label)
    fprintf('Creating Figure 2: Stratified Performance...\n');
    fig2 = figure('Position', [100, 100, 1400, 750], 'Color', 'k');
    
    % SNR Improvement by Level
    subplot(2, 2, 1);
    set(gca, 'Layer', 'top'); 
    b1 = bar(stratified_results.avg_snr_improvement, 'FaceColor', color_improvement, 'EdgeColor', 'k');
    set(gca, 'XTickLabel', stratified_results.bin_label, 'FontSize', 11);
    xtickangle(45);
    ylabel('SNR Improvement (dB)', 'FontSize', 13, 'FontWeight', 'bold');
    title('SNR Improvement by Input Level', 'FontSize', 14, 'FontWeight', 'bold');
    grid on; box on;
    hold on;
    yline(0, 'k--', 'LineWidth', 2, 'Alpha', 0.7);
    % Add value labels on bars
    vals = stratified_results.avg_snr_improvement;
    r = max(vals) - min(vals);
    
    for i = 1:length(vals)
        val = vals(i);
    
        % Always put label slightly above the top of the bar
        ypos = val + 0.05*r;  
        txtColor = 'w';  % Bright color for dark background
    
        text(i, ypos, sprintf('%.2f', val), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontWeight', 'bold', ...
            'Color', txtColor);
    end

    hold off;
    
    % STOI Improvement by Level
    subplot(2, 2, 2);
    b2 = bar(stratified_results.avg_stoi_improvement, 'FaceColor', color_improvement, 'EdgeColor', 'k');
    set(gca, 'XTickLabel', stratified_results.bin_label, 'FontSize', 11);
    xtickangle(45);
    ylabel('STOI Improvement', 'FontSize', 13, 'FontWeight', 'bold');
    title('STOI Improvement by Input Level', 'FontSize', 14, 'FontWeight', 'bold');
    grid on; box on;
    stoi_imp_min = min(stratified_results.avg_stoi_improvement);
    stoi_imp_max = max(stratified_results.avg_stoi_improvement);
    stoi_imp_range = stoi_imp_max - stoi_imp_min;
    if ~isnan(stoi_imp_min) && ~isnan(stoi_imp_max) && stoi_imp_range > 0
        ylim([max(0, stoi_imp_min - 0.2*stoi_imp_range), stoi_imp_max + 0.2*stoi_imp_range]);
    elseif ~isnan(stoi_imp_min) && ~isnan(stoi_imp_max) && stoi_imp_min == stoi_imp_max
        ylim([stoi_imp_min - 0.1, stoi_imp_min + 0.1]);
    end
    hold on;
    yline(0, 'k--', 'LineWidth', 2, 'Alpha', 0.7);
    % Add value labels
    for i = 1:length(stratified_results.avg_stoi_improvement)
        val = stratified_results.avg_stoi_improvement(i);
        if ~isnan(val)
            text(i, val, sprintf('%.3f', val), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 10, 'FontWeight', 'bold');
        end
    end
    hold off;
    
    % Input vs Output SNR
    subplot(2, 2, 3);
    b3 = bar([stratified_results.avg_input_snr; stratified_results.avg_output_snr]', ...
        'grouped', 'EdgeColor', 'k');
    b3(1).FaceColor = color_input;
    b3(2).FaceColor = color_output;
    set(gca, 'XTickLabel', stratified_results.bin_label, 'FontSize', 11);
    xtickangle(45);
    ylabel('SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
    title('Input vs Output SNR by Level', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Input', 'Output', 'Location', 'northwest', 'Box', 'off', 'FontSize', 11);
    grid on; box on;

    ylim([-7 15]);

    
    % Sample Distribution
    subplot(2, 2, 4);
    b4 = bar(stratified_results.n_files, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'k');
    set(gca, 'XTickLabel', stratified_results.bin_label, 'FontSize', 11);
    xtickangle(45);
    ylabel('Number of Files', 'FontSize', 13, 'FontWeight', 'bold');
    title('Sample Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    grid on; box on;
    % Add count labels
    for i = 1:length(stratified_results.n_files)
        text(i, stratified_results.n_files(i), sprintf('%d', stratified_results.n_files(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 11, 'FontWeight', 'bold');
    end
    
    sgtitle('Stratified Performance Analysis', 'FontSize', 17, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'stratified_performance.png'));
    fprintf('  ✓ Saved: stratified_performance.png\n');
end

%% Figure 3: Improvement Scatter - IMPROVED
fprintf('Creating Figure 3: Improvement Analysis...\n');
fig3 = figure('Position', [100, 100, 1400, 600], 'Color', 'k');

subplot(1, 2, 1);
scatter(results.SNR_input, results.SNR_improvement, 90, results.SNR_input, ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
colormap(gca, parula);
cb1 = colorbar;
cb1.Label.String = 'Input SNR (dB)';
cb1.Label.FontSize = 12;
cb1.Label.FontWeight = 'bold';
set(gca, 'FontSize', 12);
xlabel('Input SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('SNR Improvement (dB)', 'FontSize', 13, 'FontWeight', 'bold');
title('SNR Improvement vs Input Level', 'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;
hold on;
yline(0, 'r--', 'LineWidth', 2.5, 'Label', 'No Change', 'LabelHorizontalAlignment', 'left', 'FontSize', 11);
% Add trend line
p = polyfit(results.SNR_input, results.SNR_improvement, 1);
x_fit = linspace(min(results.SNR_input), max(results.SNR_input), 100);
y_fit = polyval(p, x_fit);
plot(x_fit, y_fit, 'k-', 'LineWidth', 2, 'DisplayName', 'Trend');
hold off;

subplot(1, 2, 2);
scatter(results.SNR_input, results.STOI_improvement, 90, results.SNR_input, ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
colormap(gca, parula);
cb2 = colorbar;
cb2.Label.String = 'Input SNR (dB)';
cb2.Label.FontSize = 12;
cb2.Label.FontWeight = 'bold';
set(gca, 'FontSize', 12);
xlabel('Input SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('STOI Improvement', 'FontSize', 13, 'FontWeight', 'bold');
title('STOI Improvement vs Input Level', 'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;
stoi_imp_min = min(results.STOI_improvement);
stoi_imp_max = max(results.STOI_improvement);
stoi_imp_range = stoi_imp_max - stoi_imp_min;
if ~isnan(stoi_imp_min) && ~isnan(stoi_imp_max) && stoi_imp_range > 0
    ylim([stoi_imp_min - 0.2*stoi_imp_range, stoi_imp_max + 0.2*stoi_imp_range]);
end
hold on;
yline(0, 'r--', 'LineWidth', 2.5, 'Label', 'No Change', 'LabelHorizontalAlignment', 'left', 'FontSize', 11);
% Add trend line if we have valid STOI values
valid_stoi_idx = ~isnan(results.SNR_input) & ~isnan(results.STOI_improvement);
if sum(valid_stoi_idx) >= 2 && exist('x_fit', 'var')
    p_stoi = polyfit(results.SNR_input(valid_stoi_idx), results.STOI_improvement(valid_stoi_idx), 1);
    y_fit_stoi = polyval(p_stoi, x_fit);
    plot(x_fit, y_fit_stoi, 'k-', 'LineWidth', 2, 'DisplayName', 'Trend');
end
hold off;

sgtitle('Improvement Analysis by Input SNR', 'FontSize', 17, 'FontWeight', 'bold');
saveas(fig3, fullfile(results_folder, 'improvement_analysis.png'));
fprintf('  ✓ Saved: improvement_analysis.png\n');

%% Figure 4: Input vs Output Scatter - IMPROVED
fprintf('Creating Figure 4: Input vs Output Comparison...\n');
fig4 = figure('Position', [100, 100, 1200, 600], 'Color', 'k');

subplot(1, 2, 1);
scatter(results.SNR_input, results.SNR_output, 70, color_output, ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 0.7);
hold on;
max_snr = max([results.SNR_input, results.SNR_output]);
min_snr = min([results.SNR_input, results.SNR_output]);
plot([min_snr, max_snr], [min_snr, max_snr], 'r--', 'LineWidth', 2.5, 'DisplayName', 'No Improvement');
set(gca, 'FontSize', 12);
xlabel('Input SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Output SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
title('SNR: Input vs Output', 'FontSize', 14, 'FontWeight', 'bold');
legend('Test Files', 'No Improvement', 'Location', 'northwest', 'Box', 'off', 'FontSize', 11);
grid on; box on;
axis square;
xlim([min_snr - 2, max_snr + 2]);
ylim([min_snr - 2, max_snr + 2]);
hold off;

subplot(1, 2, 2);
scatter(results.STOI_input, results.STOI_output, 70, color_output, ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'MarkerFaceAlpha', 0.7);
hold on;
stoi_all_min = min([results.STOI_input, results.STOI_output]);
stoi_all_max = max([results.STOI_input, results.STOI_output]);
if ~isnan(stoi_all_min) && ~isnan(stoi_all_max)
    plot([stoi_all_min, stoi_all_max], [stoi_all_min, stoi_all_max], ...
        'r--', 'LineWidth', 2.5, 'DisplayName', 'No Improvement');
end
set(gca, 'FontSize', 12);
xlabel('Input STOI', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Output STOI', 'FontSize', 13, 'FontWeight', 'bold');
title('STOI: Input vs Output', 'FontSize', 14, 'FontWeight', 'bold');
legend('Test Files', 'No Improvement', 'Location', 'northwest', 'Box', 'off', 'FontSize', 11);
grid on; box on;
if ~isnan(stoi_all_min) && ~isnan(stoi_all_max)
    stoi_range = stoi_all_max - stoi_all_min;
    if stoi_range > 0
        xlim([max(0, stoi_all_min - 0.05*stoi_range), min(1, stoi_all_max + 0.05*stoi_range)]);
        ylim([max(0, stoi_all_min - 0.05*stoi_range), min(1, stoi_all_max + 0.05*stoi_range)]);
    end
end
axis square;
hold off;


axs = findall(gcf, 'Type', 'Axes');
for ax = axs'
    pos = ax.Position;
    pos(2) = pos(2) - 0.05;   % shift down
    pos(4) = pos(4) - 0.03;   % shrink height slightly
    ax.Position = pos;
end

sgtitle('Input vs Output Performance', 'FontSize', 17, 'FontWeight', 'bold');
saveas(fig4, fullfile(results_folder, 'input_vs_output_scatter.png'));
fprintf('  ✓ Saved: input_vs_output_scatter.png\n');

%% Figure 5: Per-File Improvements - IMPROVED
fprintf('Creating Figure 5: Per-File Improvements...\n');
fig5 = figure('Position', [100, 100, 1400, 750], 'Color', 'k');

x_vals = 1:length(results.SNR_input);

subplot(2, 1, 1);
b_snr = bar(x_vals, results.SNR_improvement, 'FaceColor', color_improvement, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.8);
set(gca, 'FontSize', 12);
xlabel('File Index', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('SNR Improvement (dB)', 'FontSize', 13, 'FontWeight', 'bold');
title('SNR Improvement per File', 'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;
hold on;
yline(avg_SNR_improvement, 'w-', 'LineWidth', 2.5, ...
    'Label', sprintf('Mean: %.2f dB', avg_SNR_improvement), ...
    'LabelHorizontalAlignment', 'left', 'FontSize', 11);
yline(0, 'k--', 'LineWidth', 1.5);
hold off;
xlim([0, length(x_vals) + 1]);

subplot(2, 1, 2);
b_stoi = bar(x_vals, results.STOI_improvement, 'FaceColor', color_improvement, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.8);
set(gca, 'FontSize', 12);
xlabel('File Index', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('STOI Improvement', 'FontSize', 13, 'FontWeight', 'bold');
title('STOI Improvement per File', 'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;
stoi_imp_min = min(results.STOI_improvement);
stoi_imp_max = max(results.STOI_improvement);
stoi_imp_range = stoi_imp_max - stoi_imp_min;
if ~isnan(stoi_imp_min) && ~isnan(stoi_imp_max) && stoi_imp_range > 0
    ylim([stoi_imp_min - 0.15*stoi_imp_range, stoi_imp_max + 0.15*stoi_imp_range]);
end
hold on;
if ~isnan(avg_STOI_improvement)
    yline(avg_STOI_improvement, 'w-', 'LineWidth', 2.5, ...
        'Label', sprintf('Mean: %.3f', avg_STOI_improvement), ...
        'LabelHorizontalAlignment', 'left', 'FontSize', 11);
end
yline(0, 'k--', 'LineWidth', 1.5);
hold off;
xlim([0, length(x_vals) + 1]);

sgtitle('Per-File Performance Improvements', 'FontSize', 17, 'FontWeight', 'bold');
saveas(fig5, fullfile(results_folder, 'per_file_improvements.png'));
fprintf('  ✓ Saved: per_file_improvements.png\n');

% Reset default properties
set(0, 'DefaultAxesFontSize', 'remove');
set(0, 'DefaultAxesFontName', 'remove');
set(0, 'DefaultLineLineWidth', 'remove');

%% ====== STEP 6: STATISTICAL SIGNIFICANCE TESTS (LOGGING) ======
fprintf('\n========================================\n');
fprintf('STEP 6: STATISTICAL SIGNIFICANCE TESTS\n');
fprintf('========================================\n');

if successful_evals < 2
    fprintf('\nSkipping t-tests (requires at least 2 samples).\n');
else
    % --- SNR Paired t-test Log ---
    fprintf('\n--- SNR Paired t-test ---\n');
    fprintf('Null hypothesis: No difference between input and output SNR\n');
    if h_snr == 1
        fprintf('Result: REJECT null hypothesis (p = %.4f)\n', p_snr);
        fprintf('Conclusion: SNR improvement is STATISTICALLY SIGNIFICANT\n');
    else
        fprintf('Result: FAIL TO REJECT null hypothesis (p = %.4f)\n', p_snr);
        fprintf('Conclusion: SNR improvement is NOT statistically significant\n');
    end
    fprintf('Mean improvement: %.2f dB\n', avg_SNR_improvement);
    fprintf('95%% Confidence Interval: [%.2f, %.2f] dB\n', ci_snr(1), ci_snr(2));
    fprintf('t-statistic: %.4f, df: %d\n', stats_snr.tstat, stats_snr.df);
    
    if abs(cohens_d_snr) < 0.2
        effect_size = 'Small effect';
    elseif abs(cohens_d_snr) < 0.5
        effect_size = 'Medium effect';
    else
        effect_size = 'Large effect';
    end
    fprintf('Effect size (Cohen''s d): %.3f (%s)\n', cohens_d_snr, effect_size);

    % --- STOI Paired t-test Log ---
    fprintf('\n--- STOI Paired t-test ---\n');
    if n_stoi_samples >= 2
        fprintf('Null hypothesis: No difference between input and output STOI\n');
        if h_stoi == 1
            fprintf('Result: REJECT null hypothesis (p = %.4f)\n', p_stoi);
            fprintf('Conclusion: STOI improvement is STATISTICALLY SIGNIFICANT\n');
        else
            fprintf('Result: FAIL TO REJECT null hypothesis (p = %.4f)\n', p_stoi);
            fprintf('Conclusion: STOI improvement is NOT statistically significant\n');
        end
        fprintf('Mean improvement: %.4f\n', avg_STOI_improvement);
        fprintf('95%% Confidence Interval: [%.4f, %.4f]\n', ci_stoi(1), ci_stoi(2));
        fprintf('t-statistic: %.4f, df: %d\n', stats_stoi.tstat, stats_stoi.df);
        
        if abs(cohens_d_stoi) < 0.2
            effect_size_stoi = 'Small effect';
        elseif abs(cohens_d_stoi) < 0.5
            effect_size_stoi = 'Medium effect';
        else
            effect_size_stoi = 'Large effect';
        end
        fprintf('Effect size (Cohen''s d): %.3f (%s)\n', cohens_d_stoi, effect_size_stoi);
    else
         fprintf('Skipping STOI t-test (only %d valid samples).\n', n_stoi_samples);
    end
end


%% ====== STEP 7: PRACTICAL SIGNIFICANCE ANALYSIS (LOGGING) ======
fprintf('\n========================================\n');
fprintf('STEP 7: PRACTICAL SIGNIFICANCE ANALYSIS\n');
fprintf('========================================\n');

if successful_evals == 0
    fprintf('Skipping practical significance analysis (no successful evaluations).\n');
else
    fprintf('\nFiles showing improvement:\n');
    fprintf('  SNR:  %d/%d (%.1f%%)\n', num_improved_snr, n_samples, pct_improved_snr);
    fprintf('  STOI: %d/%d (%.1f%%)\n', num_improved_stoi, n_samples, pct_improved_stoi);

    fprintf('\nFiles exceeding Just Noticeable Difference (JND):\n');
    fprintf('  SNR (> %.1f dB):  %d/%d (%.1f%%)\n', JND_SNR, num_above_jnd_snr, n_samples, pct_above_jnd_snr);
    fprintf('  STOI (> %.2f):    %d/%d (%.1f%%)\n', JND_STOI, num_above_jnd_stoi, n_samples, pct_above_jnd_stoi);
    
    fprintf('\n--- Overall Assessment ---\n');
    
    % Check for Practical Significance
    is_snr_practically_significant = avg_SNR_improvement > JND_SNR && pct_improved_snr > 70;
    is_stoi_practically_significant = avg_STOI_improvement > JND_STOI && pct_improved_stoi > 70;

    if is_snr_practically_significant
        fprintf('Model shows PRACTICALLY SIGNIFICANT improvement in SNR\n');
    else
        fprintf('  Model improvement in SNR may not be practically significant\n');
    end
    
    if is_stoi_practically_significant
        fprintf('Model shows PRACTICALLY SIGNIFICANT improvement in STOI\n');
    else
        fprintf('  Model improvement in STOI may not be practically significant\n');
    end
end

%% ====== STEP 8: KEY FINDINGS SUMMARY (LOGGING) ======
fprintf('\n========================================\n');
fprintf('KEY FINDINGS SUMMARY\n');
fprintf('========================================\n');

fprintf('\n=== SCALE-INVARIANT METRIC (STOI) ===\n');
fprintf('Files improved: %.1f%%\n', pct_improved_stoi);
if successful_evals >= 2 && exist('p_stoi', 'var') && isscalar(p_stoi) && ~isnan(p_stoi)
    fprintf('Mean improvement: %.3f (p = %.4f)\n', avg_STOI_improvement, p_stoi);
    if h_stoi == 1
        fprintf('Result: STATISTICALLY SIGNIFICANT\n');
    end
else
    fprintf('Mean improvement: %.3f\n', avg_STOI_improvement);
end

fprintf('\n=== SNR METRIC (varies with mixing) ===\n');
fprintf('  Files improved: %.1f%%\n', pct_improved_snr);
fprintf('  Mean improvement: %.2f dB (%.1f%% relative)\n', avg_SNR_improvement, avg_SNR_improvement_ratio);
fprintf('  Input SNR range: %.2f to %.2f dB\n', min_snr_input, max_snr_input);
fprintf('  Note: See stratified analysis for performance by input level\n');

fprintf('\n=== RECOMMENDATION ===\n');
if pct_improved_stoi > 80 && avg_STOI_improvement > 0.03
    fprintf('Model demonstrates ROBUST improvement across varying noise conditions\n');
    fprintf('STOI improvements indicate enhanced speech intelligibility\n');
else
    fprintf('  Model shows modest improvements; consider further training\n');
end


%% ====== FINAL SUMMARY (LOGGING) ======
fprintf('\n========================================\n');
fprintf('EVALUATION PIPELINE COMPLETE!\n');
fprintf('========================================\n');
fprintf('Total files processed: %d\n', successful_evals);
fprintf('Results saved to: %s\n\n', results_folder);
fprintf('Generated files:\n');
fprintf('  - evaluation_results.csv (Data Log)\n');
fprintf('  - stratified_results.csv (Data Log)\n');
fprintf('  - plotting_data.mat (Data for Plots)\n');
fprintf('  - distribution_comparison.png\n');
fprintf('  - stratified_performance.png\n');
fprintf('  - improvement_analysis.png\n');
fprintf('  - input_vs_output_scatter.png\n');
fprintf('  - per_file_improvements.png\n');

fprintf('\nDate completed: %s\n', datestr(now));
fprintf('========================================\n');
diary off; % Stop logging for the plotting script