% in run_test_processing.m

% TEST STEP 1 OF 3: Model Processing Pipeline
% This script processes test audio files through the trained CNN-LSTM model.
% It performs preprocessing, model inference, and postprocessing to generate denoised audio files. Run this first before evaluation scripts.

% Inputs:  Raw test audio files (test_clean, test_noise, test_combined)
% Outputs: Denoised audio files in TEST-POST folder, as well as intermediary steps (TEST-PRE, TEST-MODEL)
% Next:    Run compute_evaluation_metrics.m


clc; clear; close all;
fprintf('=== CNN-LSTM Test Data Processing Pipeline ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% ====== CONFIGURATION ======
% Paths
model_file = 'cnn_lstm_model_fixed_5000.mat';
if ~exist(model_file, 'file')
    model_file = '../cnn_lstm_model_fixed.mat';
end
if ~exist(model_file, 'file')
    model_file = 'cnn_lstm_model_fixed.mat';
end
if ~exist(model_file, 'file')
    model_file = '../train_model files/cnn_lstm_model_fixed.mat';
end

test_base_dir = '.';
test_clean_folder = fullfile(test_base_dir, 'test_clean');
test_noise_folder = fullfile(test_base_dir, 'test_noise');
test_mixed_folder = fullfile(test_base_dir, 'test_combined');

% Output folders
preprocessed_folder = 'TEST-PRE';
model_output_folder = 'TEST-MODEL';
postprocessed_folder = 'TEST-POST';

% Audio parameters
fs = 16000; % Target sampling rate

% Create output directories
folders_to_create = {preprocessed_folder, model_output_folder, postprocessed_folder};
for i = 1:length(folders_to_create)
    if ~exist(folders_to_create{i}, 'dir')
        mkdir(folders_to_create{i});
    end
end


%% ====== STEP 1: LOAD MODEL ======
fprintf('\n========================================\n');
fprintf('STEP 1: LOADING TRAINED MODEL\n');
fprintf('========================================\n');

if ~exist(model_file, 'file')
    error('Model file not found: %s', model_file);
end

try
    load(model_file, 'net');
    fprintf('Model loaded successfully\n');
catch ME
    error('Failed to load model: %s', ME.message);
end

%% ====== STEP 2: VERIFY TEST DATA ======
fprintf('\n========================================\n');
fprintf('STEP 2: VERIFYING TEST DATA\n');
fprintf('========================================\n');

% Check if test folders exist
folders_to_check = {test_clean_folder, test_noise_folder, test_mixed_folder};
folder_names = {'Clean', 'Noise', 'Combined'};

for i = 1:length(folders_to_check)
    if ~exist(folders_to_check{i}, 'dir')
        error('%s folder not found: %s', folder_names{i}, folders_to_check{i});
    else
        num_files = length(dir(fullfile(folders_to_check{i}, '*.wav')));
        fprintf('%s folder: %d WAV files found\n', folder_names{i}, num_files);
    end
end

%% ====== STEP 3: PREPROCESSING ======
fprintf('\n========================================\n');
fprintf('STEP 3: PREPROCESSING TEST FILES\n');
fprintf('========================================\n');

try
    fprintf('Running preprocessing (this may take several minutes)...\n');
    preprocessing_ratio_no_segments_function(test_mixed_folder, test_clean_folder, test_noise_folder, preprocessed_folder);
    fprintf('Preprocessing complete\n');
catch ME
    error('Preprocessing failed: %s', ME.message);
end

%% ====== STEP 4: MODEL INFERENCE ======
fprintf('\n========================================\n');
fprintf('STEP 4: RUNNING MODEL INFERENCE\n');
fprintf('========================================\n');

% Get all preprocessed files
preprocessed_files = dir(fullfile(preprocessed_folder, '*_STFT_ratio.mat'));
fprintf('Found %d preprocessed files\n', numel(preprocessed_files));

if isempty(preprocessed_files)
    error('No preprocessed files found in: %s', preprocessed_folder);
end

% Process each file through the model
successful_predictions = 0;
failed_predictions = 0;

% Disable warnings temporarily to reduce clutter
warning('off', 'all');

for i = 1:numel(preprocessed_files)
    % Only log progress every 100 files
    if mod(i, 100) == 0
        fprintf('[%d/%d] Processing...\n', i, numel(preprocessed_files));
    end
    
    try
        % Load preprocessed data
        filePath = fullfile(preprocessed_folder, preprocessed_files(i).name);
        data = load(filePath);
        
        if ~isfield(data, 'predictors')
            failed_predictions = failed_predictions + 1;
            continue;
        end
        
        predictors = data.predictors;
        
        % Prepare input for network
        XTest = reshape(predictors, size(predictors, 1), size(predictors, 2), 1);
        
        % Run prediction
        YPred = predict(net, XTest);
        
        % Squeeze output to 2D
        if ndims(YPred) > 2
            YPred = squeeze(YPred);
        end
        
        % Save model prediction along with original data
        output_data = data;
        output_data.model_prediction = YPred;
        output_data.original_predictors = predictors;
        output_data.cleanPhase_aligned = data.cleanPhase_aligned;
        
        [~, name, ~] = fileparts(preprocessed_files(i).name);
        output_file = fullfile(model_output_folder, [name '_predicted.mat']);
        save(output_file, '-struct', 'output_data');
        
        successful_predictions = successful_predictions + 1;
        
    catch ME
        failed_predictions = failed_predictions + 1;
    end
end

warning('on', 'all');

fprintf('Model inference complete\n');
fprintf('  Successful: %d, Failed: %d\n', successful_predictions, failed_predictions);

%% ====== STEP 5: POSTPROCESSING ======
fprintf('\n========================================\n');
fprintf('STEP 5: POSTPROCESSING PREDICTIONS\n');
fprintf('========================================\n');

try
    fprintf('Running postprocessing (this may take several minutes)...\n');
    postprocessing_ratio_no_segments_function;
    fprintf('Postprocessing complete\n');
catch ME
    error('Postprocessing failed: %s', ME.message);
end

%% ====== PROCESSING COMPLETE ======
fprintf('\n========================================\n');
fprintf('PROCESSING PIPELINE COMPLETE\n');
fprintf('========================================\n');
fprintf('Total predictions: %d\n', successful_predictions);
fprintf('Outputs saved to:\n');
fprintf('  - %s (preprocessed data)\n', preprocessed_folder);
fprintf('  - %s (model predictions)\n', model_output_folder);
fprintf('  - %s (denoised audio)\n', postprocessed_folder);
fprintf('\nNext step: Run evaluation_calculations_only.m\n');
fprintf('Date completed: %s\n', datestr(now));
fprintf('========================================\n\n');