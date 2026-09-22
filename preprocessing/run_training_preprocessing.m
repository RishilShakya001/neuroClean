% run_training_preprocessing.m
% Wrapper script to execute the preprocessing pipeline for model training data.
% The script defines input/output directories and calls the core preprocessing function.
%
% NOTE: This file assumes the existence of 'preprocessing_ratio_no_segments_function.m'
% in the same directory or on the MATLAB path.

clc; clear; close all;
fprintf('=== CNN-LSTM Training Data Preprocessing Wrapper ===\n');
fprintf('Date: %s\n\n', string(datetime("now")));

%% ====== CONFIGURATION: FILE PATHS ======

% Base directory for the training data (Default to current script directory)
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
training_base_dir = scriptDir;

% Input folders containing the raw audio files
combined_folder = fullfile(training_base_dir, 'combined_audio_output');
if ~exist(combined_folder, 'dir')
    combined_folder = fullfile(training_base_dir, 'train_combined');
end
speech_folder   = fullfile(training_base_dir, 'train_clean');    % Folder with clean speech files
noise_folder    = fullfile(training_base_dir, 'train_noise');    % Folder with noise files

% Output folder where the .mat files (STFT, IRM, etc.) will be saved
preprocessed_folder = fullfile(training_base_dir, 'TRAIN-PRE'); % Output folder name

%% ====== INPUT VALIDATION & SETUP ======

fprintf('Verifying input paths...\n');

% If clean/noise/combined folders don't exist, run combine_voice_with_noise to generate samples
if ~exist(combined_folder, 'dir') || ~exist(speech_folder, 'dir') || ~exist(noise_folder, 'dir')
    fprintf('Input folders missing. Running combine_voice_with_noise to create training samples...\n');
    combine_voice_with_noise(speech_folder, noise_folder, combined_folder);
end

% Create the output directory if it doesn't exist
if ~exist(preprocessed_folder, 'dir')
    mkdir(preprocessed_folder);
    fprintf('Created output folder: %s\n', preprocessed_folder);
end

%% ====== CALL PREPROCESSING FUNCTION ======

fprintf('\n========================================\n');
fprintf('STARTING PREPROCESSING\n');
fprintf('========================================\n');

try
    % Call the core function with the defined paths
    preprocessing_ratio_no_segments_function(...
        combined_folder, ...   % Input 1: combinedFolder
        speech_folder, ...     % Input 2: speechFolder
        noise_folder, ...      % Input 3: noiseFolder
        preprocessed_folder);  % Input 4: preprocessedFolder
    fprintf('Preprocessing finished successfully.\n');
catch ME
    error('Preprocessing failed: %s\n', ME.message);
end

%% ====== SCRIPT COMPLETE ======

fprintf('\n========================================\n');
fprintf('PREPROCESSING PIPELINE COMPLETE\n');
fprintf('Outputs saved to: %s\n', preprocessed_folder);
fprintf('========================================\n');