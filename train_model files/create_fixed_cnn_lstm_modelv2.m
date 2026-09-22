function layers = create_fixed_cnn_lstm_modelv2(numFeatures)
  % CREATE_FIXED_CNN_LSTM_MODELV2 - Build a fixed CNN+LSTM sequence model
  %
  % Input arguments:
  % numFeatures - number of features per time step (e.g., 257)
  %
  % Output arguments:
  % layers - Layer array for sequence-to-sequence regression
    % Model for sequence-to-sequence prediction with variable-length sequences
    % Input: [257 × variable_timeframes]
    % Output: [257 × variable_timeframes]
    
    layers = [
        sequenceInputLayer(numFeatures, 'Name', 'input')
        
        % First LSTM Block (Temporal patterns)
        lstmLayer(256, 'OutputMode', 'sequence', 'Name', 'lstm1')
        dropoutLayer(0.2, 'Name', 'drop1')
        
        % Second LSTM (Deeper temporal processing)
        lstmLayer(128, 'OutputMode', 'sequence', 'Name', 'lstm2')
        dropoutLayer(0.2, 'Name', 'drop2')
        
        % CNN Block (Local frequency pattern extraction)
        % Use 1-D convolutions to learn local patterns along the feature axis
        convolution1dLayer(5, 128, 'Padding', 'same', 'Name', 'conv1')
        batchNormalizationLayer('Name', 'bn1')
        reluLayer('Name', 'relu1')
        dropoutLayer(0.2, 'Name', 'drop3')
        
        convolution1dLayer(3, 64, 'Padding', 'same', 'Name', 'conv2')
        batchNormalizationLayer('Name', 'bn2')
        reluLayer('Name', 'relu2')
        
        convolution1dLayer(3, 32, 'Padding', 'same', 'Name', 'conv3')
        batchNormalizationLayer('Name', 'bn3')
        reluLayer('Name', 'relu3')
        
        % Final LSTM for temporal integration
        lstmLayer(128, 'OutputMode', 'sequence', 'Name', 'lstm3')
        dropoutLayer(0.3, 'Name', 'drop4')
        
        % Output mapping (returns sequence of predictions)
        fullyConnectedLayer(numFeatures, 'Name', 'fc')
        
        % Regression layer for sequence-to-sequence
        regressionLayer('Name', 'regression')
    ];
    
    fprintf('CNN+LSTM model created (%d layers)\n', numel(layers));
    fprintf('Architecture: Input[%d] -> LSTM -> CNN -> LSTM -> Output[%d]\n', ...
        numFeatures, numFeatures);
end