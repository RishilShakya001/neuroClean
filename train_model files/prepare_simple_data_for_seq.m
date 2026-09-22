function [XTrain, YTrain, XVal, YVal, numFeatures] = prepare_simple_data_for_seq(data, val_frac)
  % PREPARE_SIMPLE_DATA_FOR_SEQ - Prepare and split sequence predictor/target cells
  %
  % Input arguments:
  % data     - struct with fields 'predictors' and 'targets' (cell arrays)
  % val_frac - fraction of data to reserve for validation (optional)
  %
  % Output arguments:
  % XTrain, YTrain - cell arrays for training sequences
  % XVal, YVal     - cell arrays for validation sequences
  % numFeatures    - number of features (rows) in each sequence
    if nargin < 2
        val_frac = 0.2;
    end
    
    predictors = data.predictors; % Cell array of [257 × timeframes]
    targets = data.targets;       % Cell array of [257 × timeframes]
    
    N = numel(predictors);        % number of samples
    numFeatures = size(predictors{1}, 1); % 257
    
    % Process and align dimensions
    % Preallocate cell arrays and track skipped short sequences.
    X = cell(N, 1);
    Y = cell(N, 1);
    skipped = 0;
    
    for i = 1:N
        pred = predictors{i};  % [257 × timeframes]
        targ = targets{i};     % [257 × timeframes]
        
        % Get the minimum length (trim to match)
        predLen = size(pred, 2);
        targLen = size(targ, 2);
        minLen = min(predLen, targLen);
        
        % Skip sequences that are too short
        if minLen < 10
            skipped = skipped + 1;
            continue;
        end
        
        % Trim both to the same length
        X{i} = pred(:, 1:minLen);
        Y{i} = targ(:, 1:minLen);
        
        % Warn if there's a significant mismatch
        if abs(predLen - targLen) > 5
            warning('Sample %d: Large length mismatch (pred=%d, targ=%d), trimmed to %d', ...
                i, predLen, targLen, minLen);
        end
    end
    
    % Remove empty cells (skipped samples)
    X = X(~cellfun('isempty', X));
    Y = Y(~cellfun('isempty', Y));
    N = numel(X);
    
    if skipped > 0
        fprintf('Skipped %d samples (too short)\n', skipped);
    end
    
    % Split into training and validation
    % Use fixed RNG for reproducible splits.
    rng(42);
    idx = randperm(N);
    nVal = round(val_frac * N);
    valIdx = idx(1:nVal);
    trainIdx = idx(nVal+1:end);
    
    XTrain = X(trainIdx);
    YTrain = Y(trainIdx);
    XVal   = X(valIdx);
    YVal   = Y(valIdx);
    
    % Display info about sequence lengths
    trainLengths = cellfun(@(x) size(x,2), XTrain);
    valLengths = cellfun(@(x) size(x,2), XVal);
    
    fprintf('Prepared sequence data: train=%d, val=%d, features=%d\n', ...
        numel(XTrain), numel(XVal), numFeatures);
    fprintf('Training sequence lengths: min=%d, max=%d, mean=%.1f\n', ...
        min(trainLengths), max(trainLengths), mean(trainLengths));
    fprintf('Validation sequence lengths: min=%d, max=%d, mean=%.1f\n', ...
        min(valLengths), max(valLengths), mean(valLengths));
end