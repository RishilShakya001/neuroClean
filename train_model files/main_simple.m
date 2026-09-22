clc; clear; close all;
fprintf('=== CNN + LSTM Training ===\n');
% === Load multiple .mat files from a folder ===
dataFolder = '../preprocessing/TRAIN-PRE';
if ~exist(dataFolder, 'dir')
    dataFolder = 'TRAIN-PRE';
end
if ~exist(dataFolder, 'dir')
    dataFolder = '../testing_and_evaluation/TEST-PRE';
end
if ~exist(dataFolder, 'dir')
    dataFolder = '../TEST-PRE';
end
matFiles = dir(fullfile(dataFolder, '*.mat'));
% Initialize storage cells (use cells for variable-length sequences)
allPredictors = {};
allTargets = {};
fprintf('Loading %d .mat files...\n', numel(matFiles));
for k = 1:numel(matFiles)
    filePath = fullfile(dataFolder, matFiles(k).name);
    temp = load(filePath);
    
    % Check that predictors and targets exist
    if isfield(temp, 'predictors') && isfield(temp, 'targets')
        allPredictors{end+1} = temp.predictors;  % [257 × timeframes]
        allTargets{end+1} = temp.targets;        % [257 × timeframes]
        fprintf('Loaded: %s (size: %d×%d)\n', matFiles(k).name, size(temp.predictors, 1), size(temp.predictors, 2));
    else
        warning('Skipping %s (missing predictors or targets)', matFiles(k).name);
    end
end
% Create data struct with cell arrays
data.predictors = allPredictors;
data.targets = allTargets;
fprintf('\nTotal files loaded: %d\n', numel(data.predictors));
fprintf('Files have variable lengths (supports variable-length sequences)\n');
% === Prepare training data ===
% Prepare training/validation split and return feature count
[XTrain, YTrain, XVal, YVal, numFeatures] = prepare_simple_data_for_seq(data, 0.2);
% Debug: Check data format
fprintf('\nData format check:\n');
fprintf('XTrain{1} size: [%d × %d]\n', size(XTrain{1}, 1), size(XTrain{1}, 2));
fprintf('YTrain{1} size: [%d × %d]\n', size(YTrain{1}, 1), size(YTrain{1}, 2));
fprintf('XTrain is cell: %d, YTrain is cell: %d\n', iscell(XTrain), iscell(YTrain));
% === Create model ===
% Build CNN+LSTM architecture parameterized by numFeatures
layers = create_fixed_cnn_lstm_modelv2(numFeatures);
% === Training options WITHOUT CHECKPOINTS ===
options = trainingOptions('adam', ...
    'MaxEpochs', 50, ...
    'MiniBatchSize', 8, ...
    'InitialLearnRate', 0.001, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {XVal, YVal}, ...
    'ValidationFrequency', 30, ...
    'Plots', 'training-progress', ...
    'Verbose', true, ...
    'GradientThreshold', 1);
% === Train network from scratch ===
fprintf('\nStarting training from scratch...\n');
net = trainNetwork(XTrain, YTrain, layers, options);
% === Save final model ===
save('cnn_lstm_model_fixed.mat', 'net');
fprintf('\n=== Training Complete ===\n');
fprintf('Final model saved: cnn_lstm_model_fixed.mat\n');
