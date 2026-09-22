% in compute_evaluation_metrics.m

% TEST STEP 2 OF 3: Metric Calculation
% This script computes evaluation metrics (SNR, STOI) by comparing denoised
% audio against clean references. Results are saved for visualization.

% Inputs:  Denoised audio from TEST-POST, reference audio from test_clean / test_noise / test_combined folders
% Outputs: Metric data saved to plotting_data.mat, CSV files
% Next:    Run generate_evaluation_report.m

clc; clear; close all;
fprintf('=== CNN-LSTM Model Evaluation Pipeline (Data Only) ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% ====== CONFIGURATION AND SETUP ======
% Paths
test_base_dir = '.';
test_clean_folder = fullfile(test_base_dir, 'test_clean');
test_noise_folder = fullfile(test_base_dir, 'test_noise');
test_mixed_folder = fullfile(test_base_dir, 'test_combined');

% Check if test directories exist and fall back to parent if needed
if ~exist(test_clean_folder, 'dir') && exist('../test_clean', 'dir')
    test_base_dir = '..';
    test_clean_folder = fullfile(test_base_dir, 'test_clean');
    test_noise_folder = fullfile(test_base_dir, 'test_noise');
    test_mixed_folder = fullfile(test_base_dir, 'test_combined');
end

% Input folders (ALREADY PROCESSED)
postprocessed_folder = 'TEST-POST';  % Folder with denoised audio files
results_folder = 'TEST-RESULTS-FINAL';
% Audio parameters
fs = 16000; % Target sampling rate
% Create results directory if needed
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

% Start logging all console output
common_diary_file = fullfile(results_folder, 'final_evaluation_log.txt');
diary(common_diary_file); % Start logging (creates the file)
diary on;

%% ====== STEP 1: VERIFY INPUT DATA ======
fprintf('\n========================================\n');
fprintf('STEP 1: VERIFYING INPUT DATA\n');
fprintf('========================================\n');
% Check if test folders exist
folders_to_check = {test_clean_folder, test_noise_folder, test_mixed_folder, postprocessed_folder};
folder_names = {'Clean', 'Noise', 'Combined', 'Postprocessed (Denoised)'};
for i = 1:length(folders_to_check)
    if ~exist(folders_to_check{i}, 'dir')
        error('%s folder not found: %s', folder_names{i}, folders_to_check{i});
    else
        num_files = length(dir(fullfile(folders_to_check{i}, '*.wav')));
        fprintf('%s folder: %d WAV files found\n', folder_names{i}, num_files);
    end
end

%% ====== STEP 2: EVALUATION METRICS ======
fprintf('\n========================================\n');
fprintf('STEP 2: COMPUTING EVALUATION METRICS\n');
fprintf('========================================\n');
% Get denoised audio files
denoised_files = dir(fullfile(postprocessed_folder, '*_Predicted.wav'));
fprintf('Found %d denoised audio files.\n\n', numel(denoised_files));

if isempty(denoised_files)
    error('No denoised audio files found in: %s', postprocessed_folder);
end

% Initialize results storage
results = struct();
results.filename = {};
results.SNR_input = [];
results.SNR_output = [];
results.SNR_improvement = [];
results.SNR_improvement_ratio = []; 
results.STOI_input = [];
results.STOI_output = [];
results.STOI_improvement = [];

% Process each denoised file
successful_evals = 0;
failed_evals = 0;
skipped_silent = 0;
skipped_misaligned = 0;
total_files = numel(denoised_files);

warning('off', 'all'); 

for i = 1:total_files 
    % Log progress every 100 files
    if mod(i, 100) == 0 || i == 1
        fprintf('[%d/%d] Evaluating files...\n', i, total_files);
    end
    
    try
        % Load denoised audio
        denoised_path = fullfile(postprocessed_folder, denoised_files(i).name);
        [denoised_audio, fs_denoised] = audioread(denoised_path);
        
        if max(abs(denoised_audio)) < 1e-6
            skipped_silent = skipped_silent + 1;
            continue;
        end
        
        % Extract base filename (complex parsing logic retained)
        base_name = denoised_files(i).name;
        if endsWith(base_name, '_Predicted.wav')
            base_name = extractBefore(base_name, '_Predicted.wav');
        end
        if contains(base_name, '_STFT_ratio_predicted')
            base_name = extractBefore(base_name, '_STFT_ratio_predicted');
        end
        if endsWith(base_name, '_STFT_ratio')
            base_name = extractBefore(base_name, '_STFT_ratio');
        end
        
        parts = split(base_name, '_with_');
        if length(parts) < 2
            failed_evals = failed_evals + 1;
            continue;
        end
        
        clean_name = parts{1};
        % noise_name = parts{2}; % Not strictly needed for metrics
        
        % Build file paths
        combined_file = fullfile(test_mixed_folder, [base_name '.wav']);
        clean_file = fullfile(test_clean_folder, [clean_name '.wav']);
        
        if ~exist(combined_file, 'file') || ~exist(clean_file, 'file')
            failed_evals = failed_evals + 1;
            continue;
        end
        
        % Load audio files and resample/mono conversion (retained for robustness)
        [noisy_audio, fs_noisy] = audioread(combined_file);
        [clean_audio, fs_clean] = audioread(clean_file);
        
        if fs_noisy ~= fs
            noisy_audio = resample(noisy_audio, fs, fs_noisy);
        end
        if fs_clean ~= fs
            clean_audio = resample(clean_audio, fs, fs_clean);
        end
        if fs_denoised ~= fs
            denoised_audio = resample(denoised_audio, fs, fs_denoised);
        end
        
        if size(noisy_audio, 2) > 1
            noisy_audio = mean(noisy_audio, 2);
        end
        if size(clean_audio, 2) > 1
            clean_audio = mean(clean_audio, 2);
        end
        if size(denoised_audio, 2) > 1
            denoised_audio = mean(denoised_audio, 2);
        end
        
        % Match lengths and perform alignment (CRITICAL)
        minLen = min([length(noisy_audio), length(clean_audio), length(denoised_audio)]);
        noisy_audio = noisy_audio(1:minLen);
        clean_audio = clean_audio(1:minLen);
        denoised_audio = denoised_audio(1:minLen);

        [correlation, lags] = xcorr(clean_audio, denoised_audio);
        [~, max_idx] = max(abs(correlation));
        lag = lags(max_idx);
        
        if abs(lag) > fs
            skipped_misaligned = skipped_misaligned + 1;
            continue;
        end
        
        if lag > 0
            denoised_audio = [zeros(lag, 1); denoised_audio(1:end-lag)];
        elseif lag < 0
            denoised_audio = [denoised_audio(-lag+1:end); zeros(-lag, 1)];
        end
        
        % Calculate Noisy Audio alignment for fair comparison (retained)
        [correlation, lags] = xcorr(clean_audio, noisy_audio);
        [~, max_idx] = max(abs(correlation));
        lag_noisy = lags(max_idx);
        
        if lag_noisy > 0
            noisy_audio = [zeros(lag_noisy, 1); noisy_audio(1:end-lag_noisy)];
        elseif lag_noisy < 0
            noisy_audio = [noisy_audio(-lag_noisy+1:end); zeros(-lag_noisy, 1)];
        end

        % Compute metrics - SNR (using scale-aligned clean reference)
        % Align scaling of clean_audio to noisy_audio (least squares projection)
        alpha = (noisy_audio' * clean_audio) / (clean_audio' * clean_audio + eps);
        clean_audio_scaled_input = alpha * clean_audio;
        noise_signal_input = noisy_audio - clean_audio_scaled_input;
        
        % Align scaling of clean_audio to denoised_audio (least squares projection)
        beta = (denoised_audio' * clean_audio) / (clean_audio' * clean_audio + eps);
        clean_audio_scaled_output = beta * clean_audio;
        noise_signal_output = denoised_audio - clean_audio_scaled_output;
        
        % Compute SNR metrics
        SNR_input = snr(clean_audio_scaled_input, noise_signal_input);
        SNR_output = snr(clean_audio_scaled_output, noise_signal_output);
        SNR_improvement = SNR_output - SNR_input;
        SNR_improvement_ratio = (SNR_output - SNR_input) / (abs(SNR_input) + 1) * 100;
        
        % STOI (re-requires a valid 'stoi' function)
        try
            STOI_input = stoi(clean_audio, noisy_audio, fs);
            STOI_output = stoi(clean_audio, denoised_audio, fs);
        catch ME
            STOI_input = NaN;
            STOI_output = NaN;
            if i == 1
                fprintf('STOI calculation failed for first file. Subsequent STOI results may be NaN.\n');
            end
        end
        
        STOI_improvement = STOI_output - STOI_input;
        
        % Store results
        results.filename{end+1} = denoised_files(i).name;
        results.SNR_input(end+1) = SNR_input;
        results.SNR_output(end+1) = SNR_output;
        results.SNR_improvement(end+1) = SNR_improvement;
        results.SNR_improvement_ratio(end+1) = SNR_improvement_ratio;
        results.STOI_input(end+1) = STOI_input;
        results.STOI_output(end+1) = STOI_output;
        results.STOI_improvement(end+1) = STOI_improvement;
        
        successful_evals = successful_evals + 1;
        
    catch ME
        fprintf('  Error: %s (%s)\n', denoised_files(i).name, ME.message);
        failed_evals = failed_evals + 1;
    end
end

warning('on', 'all'); 

fprintf('\nEvaluation file processing complete!\n');
fprintf('  Successful: %d, Failed: %d, Skipped: %d\n', successful_evals, failed_evals, skipped_silent + skipped_misaligned);

if successful_evals == 0
    % Handles the case where the loop runs but finds no valid data
    fprintf('WARNING: No files were successfully evaluated. Initializing empty results for save.\n');
    avg_SNR_improvement = NaN;
    avg_STOI_improvement = NaN;
    % Ensure results_table can be created even if results fields are empty
    results_table = table(); 
else
    
    %% ====== STEP 3: COMPUTE SUMMARY STATISTICS AND AGGREGATE ======
    fprintf('\n========================================\n');
    fprintf('STEP 3: COMPUTING SUMMARY STATISTICS\n');
    fprintf('========================================\n');

    % --- COMPUTE AVERAGES AND RANGES ---
    avg_SNR_input = mean(results.SNR_input, 'omitnan');
    std_SNR_input = std(results.SNR_input, 'omitnan');
    avg_SNR_output = mean(results.SNR_output, 'omitnan');
    std_SNR_output = std(results.SNR_output, 'omitnan');
    avg_SNR_improvement = mean(results.SNR_improvement, 'omitnan');
    std_SNR_improvement = std(results.SNR_improvement, 'omitnan');
    avg_SNR_improvement_ratio = mean(results.SNR_improvement_ratio, 'omitnan');

    avg_STOI_input = mean(results.STOI_input, 'omitnan');
    std_STOI_input = std(results.STOI_input, 'omitnan');
    avg_STOI_output = mean(results.STOI_output, 'omitnan');
    std_STOI_output = std(results.STOI_output, 'omitnan');
    avg_STOI_improvement = mean(results.STOI_improvement, 'omitnan');
    std_STOI_improvement = std(results.STOI_improvement, 'omitnan');
    
    min_snr_input = min(results.SNR_input);
    max_snr_input = max(results.SNR_input);
    
    % --- LOG AVERAGE METRICS ---
    fprintf('\n=== AVERAGE METRICS ===\n');
    fprintf('SNR:\n');
    fprintf('  Input:         %.2f \\pm %.2f dB\n', avg_SNR_input, std_SNR_input);
    fprintf('  Output:        %.2f \\pm %.2f dB\n', avg_SNR_output, std_SNR_output);
    fprintf('  Improvement:   %.2f \\pm %.2f dB (%.1f%% relative improvement)\n', ...
            avg_SNR_improvement, std_SNR_improvement, avg_SNR_improvement_ratio);

    fprintf('\nSTOI (Scale-Invariant):\n');
    fprintf('  Input:  %.3f \\pm %.3f\n', avg_STOI_input, std_STOI_input);
    fprintf('  Output: %.3f \\pm %.3f\n', avg_STOI_output, std_STOI_output);
    fprintf('  Improvement: %.3f \\pm %.3f\n', avg_STOI_improvement, std_STOI_improvement);
    
    fprintf('\n=== INPUT SNR RANGE ===\n');
    fprintf('  Min Input SNR: %.2f dB\n', min_snr_input);
    fprintf('  Max Input SNR: %.2f dB\n', max_snr_input);

    % --- LOG BEST/WORST 5 ---
    
    % Sort SNR improvement
    [sorted_snr_imp, idx_snr] = sort(results.SNR_improvement, 'descend');
    
    fprintf('\n=== BEST 5 SNR IMPROVEMENTS (dB) ===\n');
    for k = 1:min(5, length(sorted_snr_imp))
        fprintf('  #%d (%.2f dB): %s\n', k, sorted_snr_imp(k), results.filename{idx_snr(k)});
    end
    
    fprintf('\n=== WORST 5 SNR IMPROVEMENTS (dB) ===\n');
    for k = 1:min(5, length(sorted_snr_imp))
        % The worst improvements are at the end of the descending list
        worst_idx = length(sorted_snr_imp) - k + 1;
        fprintf('  #%d (%.2f dB): %s\n', k, sorted_snr_imp(worst_idx), results.filename{idx_snr(worst_idx)});
    end

    % Sort STOI improvement
    [sorted_stoi_imp, idx_stoi] = sort(results.STOI_improvement, 'descend');
    
    fprintf('\n=== BEST 5 STOI IMPROVEMENTS ===\n');
    for k = 1:min(5, length(sorted_stoi_imp))
        fprintf('  #%d (%.3f): %s\n', k, sorted_stoi_imp(k), results.filename{idx_stoi(k)});
    end
    
    fprintf('\n=== WORST 5 STOI IMPROVEMENTS ===\n');
    for k = 1:min(5, length(sorted_stoi_imp))
        worst_idx = length(sorted_stoi_imp) - k + 1;
        fprintf('  #%d (%.3f): %s\n', k, sorted_stoi_imp(worst_idx), results.filename{idx_stoi(worst_idx)});
    end

    % Save main results table
    results_table = struct2table(results);
end

csv_file = fullfile(results_folder, 'evaluation_results.csv');
writetable(results_table, csv_file);
fprintf('\nResults saved to:\n');
fprintf('  - %s\n', csv_file);


%% ====== STEP 4: STRATIFIED ANALYSIS BY INPUT SNR (Includes Logging) ======
fprintf('\n========================================\n');
fprintf('STEP 4: STRATIFIED ANALYSIS BY INPUT SNR\n');
fprintf('========================================\n');

stratified_results = struct();
stratified_results.bin_label = {}; 
stratified_results.n_files = [];
stratified_results.avg_input_snr = [];
stratified_results.avg_output_snr = [];
stratified_results.avg_snr_improvement = [];
stratified_results.avg_stoi_improvement = [];

if successful_evals > 0
    % Define SNR bins
    snr_bins = [-Inf, -5, 0, 5, 10, Inf];
    bin_labels = {'Very Low (<-5dB)', 'Low (-5 to 0dB)', 'Medium (0-5dB)', ...
                  'High (5-10dB)', 'Very High (>10dB)'};
        
    for i = 1:length(bin_labels)
        idx = results.SNR_input >= snr_bins(i) & results.SNR_input < snr_bins(i+1);
        n = sum(idx);
        
        if n > 0
            avg_in = mean(results.SNR_input(idx));
            avg_out = mean(results.SNR_output(idx));
            avg_imp = mean(results.SNR_improvement(idx));
            avg_stoi_imp = mean(results.STOI_improvement(idx), 'omitnan');
            
            % Log the stratified results
            fprintf('\n%s: %d files\n', bin_labels{i}, n);
            fprintf('  Avg Input SNR:        %.2f dB\n', avg_in);
            fprintf('  Avg Output SNR:       %.2f dB\n', avg_out);
            fprintf('  Avg SNR Improvement:  %.2f dB\n', avg_imp);
            fprintf('  Avg STOI Improvement: %.3f\n', avg_stoi_imp);
            
            % Store for plotting
            stratified_results.bin_label{end+1} = bin_labels{i};
            stratified_results.n_files(end+1) = n;
            stratified_results.avg_input_snr(end+1) = avg_in;
            stratified_results.avg_output_snr(end+1) = avg_out;
            stratified_results.avg_snr_improvement(end+1) = avg_imp;
            stratified_results.avg_stoi_improvement(end+1) = avg_stoi_imp;
        end
    end
    
    % Save stratified results
    stratified_table = struct2table(stratified_results);
    stratified_csv = fullfile(results_folder, 'stratified_results.csv');
    writetable(stratified_table, stratified_csv);
    fprintf('\nStratified results saved to: %s\n', stratified_csv);
else
    fprintf('Skipping stratified analysis due to zero successful evaluations.\n');
    stratified_results = struct('bin_label', {}, 'n_files', [], 'avg_input_snr', [], 'avg_output_snr', [], 'avg_snr_improvement', [], 'avg_stoi_improvement', []);
end


%% ====== SAVE DATA FOR PLOTTING ======
data_file_name = fullfile(results_folder, 'plotting_data.mat');
% IMPORTANT: Save all necessary variables
save(data_file_name, 'results', 'stratified_results', 'avg_SNR_improvement', 'avg_STOI_improvement', 'avg_SNR_input', 'avg_SNR_output', 'avg_STOI_input', 'avg_STOI_output', 'std_SNR_input', 'std_SNR_output', 'std_SNR_improvement', 'std_STOI_input', 'std_STOI_output', 'std_STOI_improvement', 'min_snr_input', 'max_snr_input', 'avg_SNR_improvement_ratio');
fprintf('\n\n--- DATA SAVED SUCCESSFULLY ---\n');
fprintf('Plotting data saved to: %s\n', data_file_name);
fprintf('Run "plotting_script.m" to generate figures and final log.\n');
% Stop logging
diary off;