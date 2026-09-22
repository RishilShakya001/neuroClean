% run_synthetic_verification.m
% Automated script to verify the entire preprocessing, training, testing, 
% and evaluation pipeline of the speech denoising project using synthetic data.

clc; clear; close all;
fprintf('=== Starting End-to-End Pipeline Verification ===\n');

% Add dependencies to search path
addpath(pwd);
addpath(fullfile(pwd, '../preprocessing'));
addpath(fullfile(pwd, '../train_model files'));

% Set random seed for reproducibility
rng(0);

% Define folders
clean_dir = 'test_clean';
noise_dir = 'test_noise';
mixed_dir = 'test_combined';

if ~exist(clean_dir, 'dir'); mkdir(clean_dir); end
if ~exist(noise_dir, 'dir'); mkdir(noise_dir); end
if ~exist(mixed_dir, 'dir'); mkdir(mixed_dir); end

fprintf('Generating synthetic clean voice and noise WAV files...\n');
fs_v = 48000; % 48 kHz original clean voice fs
fs_n = 44100; % 44.1 kHz original noise fs
duration = 2.0; % 2 seconds each

t_v = (0:1/fs_v:duration)';
t_n = (0:1/fs_n:duration)';

% Generate 3 synthetic voice clips (combinations of formant sines with slow amplitude decay)
voice1 = (0.5 * sin(2*pi*250*t_v) + 0.3 * sin(2*pi*500*t_v) + 0.2 * sin(2*pi*1200*t_v)) .* (0.5 + 0.5 * cos(2*pi*0.5*t_v));
voice2 = (0.4 * sin(2*pi*300*t_v) + 0.4 * sin(2*pi*600*t_v) + 0.2 * sin(2*pi*1500*t_v)) .* (0.5 + 0.5 * cos(2*pi*0.55*t_v));
voice3 = (0.6 * sin(2*pi*200*t_v) + 0.2 * sin(2*pi*400*t_v) + 0.2 * sin(2*pi*1000*t_v)) .* (0.5 + 0.5 * cos(2*pi*0.45*t_v));

% Generate 3 noise clips (white noise and narrow-band engine-like tones)
noise1 = randn(size(t_n)) * 0.1;
noise2 = 0.1 * sin(2*pi*60*t_n) + randn(size(t_n)) * 0.05;
noise3 = 0.1 * sin(2*pi*120*t_n) + randn(size(t_n)) * 0.05;

% Save files
audiowrite(fullfile(clean_dir, 'p250_401_mic2_seg1.wav'), voice1, fs_v);
audiowrite(fullfile(clean_dir, 'p250_414_mic2_seg1.wav'), voice2, fs_v);
audiowrite(fullfile(clean_dir, 'p255_055_mic2_seg1.wav'), voice3, fs_v);

audiowrite(fullfile(noise_dir, 'duQjL_OBym4.wav'), noise1, fs_n);
audiowrite(fullfile(noise_dir, 'e7l0nmb0I3s.wav'), noise2, fs_n);
audiowrite(fullfile(noise_dir, 'fkPoNQzfdRI.wav'), noise3, fs_n);

% Run mixing script using local variables override
fprintf('\n--- Running combine_voice_with_noise...\n');
voice_folder = fullfile(pwd, clean_dir);
noise_folder = fullfile(pwd, noise_dir);
base_output = pwd;
run('../preprocessing/combine_voice_with_noise.m');

% Copy mixed output to test_combined folder
movefile('combined_audio_output/*.wav', mixed_dir);
rmdir('combined_audio_output');

% Preprocess mixed/clean data into STFT & IRM matrices
fprintf('\n--- Running Preprocessing Function...\n');
preprocessed_dir = 'TEST-PRE';
preprocessing_ratio_no_segments_function(mixed_dir, clean_dir, noise_dir, preprocessed_dir);

% Train a minimal model
fprintf('\n--- Training Minimal Model (1 epoch) for Verification...\n');
% Load the preprocessed mat files
matFiles = dir(fullfile(preprocessed_dir, '*.mat'));
allPredictors = {};
allTargets = {};
for k = 1:numel(matFiles)
    temp = load(fullfile(preprocessed_dir, matFiles(k).name));
    allPredictors{end+1} = temp.predictors;
    allTargets{end+1} = temp.targets;
end
data.predictors = allPredictors;
data.targets = allTargets;

[XTrain, YTrain, XVal, YVal, numFeatures] = prepare_simple_data_for_seq(data, 0.2);

% Build model
layers = create_fixed_cnn_lstm_modelv2(numFeatures);

% Extremely fast options
options = trainingOptions('adam', ...
    'MaxEpochs', 1, ...
    'MiniBatchSize', 1, ...
    'Verbose', false, ...
    'Plots', 'none');

net = trainNetwork(XTrain, YTrain, layers, options);
save('cnn_lstm_model_fixed_5000.mat', 'net');
fprintf('Saved minimal verification model to cnn_lstm_model_fixed_5000.mat\n');

% Run pipeline processing
fprintf('\n--- Running test processing...\n');
run('run_test_processing.m');

% Run metric calculation
fprintf('\n--- Running evaluation metrics calculation...\n');
run('compute_evaluation_metrics.m');

% Run report generation
fprintf('\n--- Running evaluation report generation...\n');
run('generate_evaluation_report.m');

fprintf('\n=== Verification Pipeline Finished Successfully! ===\n');
