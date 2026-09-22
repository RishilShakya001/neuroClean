function interactive_ui_denoise()
%% ------------------- SETUP -------------------
% Get actual folder containing this script (prevents pwd path resolution errors)
scriptDir = fileparts(mfilename('fullpath'));

addpath(scriptDir);
addpath(fullfile(scriptDir, '..', 'preprocessing'));
addpath(fullfile(scriptDir, '..', 'testing_and_evaluation'));
addpath(fullfile(scriptDir, '..', 'train_model files'));

% Robust candidate search for trained model file
modelCandidates = {
    fullfile(scriptDir, 'cnn_lstm_model_fixed_5000.mat'), ...
    fullfile(scriptDir, '..', 'cnn_lstm_model_fixed_5000.mat'), ...
    fullfile(scriptDir, '..', 'testing_and_evaluation', 'cnn_lstm_model_fixed_5000.mat'), ...
    fullfile(scriptDir, '..', 'train_model files', 'cnn_lstm_model_fixed.mat'), ...
    fullfile(scriptDir, '..', 'cnn_lstm_model_fixed.mat'), ...
    fullfile(scriptDir, 'cnn_lstm_model_fixed.mat')
};

modelFile = '';
for k = 1:length(modelCandidates)
    if exist(modelCandidates{k}, 'file')
        modelFile = modelCandidates{k};
        break;
    end
end

if isempty(modelFile)
    warning('Trained model file not found in paths. Please run the training script first.');
end

try
    if ~isempty(modelFile)
        modelData = load(modelFile);
        net = modelData.net;
    else
        net = [];
    end
catch ME
    warning('Could not load trained model: %s', ME.message);
    net = [];
end

% UI Figure with clean close handler
fig = uifigure('Name','Interactive Denoising UI','Position',[100 100 500 350], ...
               'CloseRequestFcn', @(src,event)closeUI(src));

function closeUI(figHandle)
    try clear sound; catch; end
    delete(figHandle);
end
uilabel(fig,'Text','Interactive Speech Denoising',...
    'Position',[100 300 300 30],'FontSize',18,'FontWeight','bold');

% Recording duration dropdown
uilabel(fig,'Text','Recording Duration:',...
    'Position',[50 240 120 22],'FontSize',12);
durationDropdown = uidropdown(fig, ...
    'Position',[180 240 100 22], ...
    'Items',{'3 sec','5 sec','10 sec','30 sec','1 min','3 min','5 min'}, ...
    'ItemsData',[3 5 10 30 60 180 300], ...
    'Value',3);

% Record button
recordBtn = uibutton(fig,'Text','🎤 Record', ...
    'Position',[50 180 180 50], ...
    'FontSize',14,...
    'ButtonPushedFcn',@(btn,event)recordCallback());

% Denoise button
denoiseBtn = uibutton(fig,'Text','🔧 Denoise', ...
    'Position',[270 180 180 50], ...
    'FontSize',14,...
    'ButtonPushedFcn',@(btn,event)denoiseCallback());

% Play buttons
playOriginalBtn = uibutton(fig,'Text','▶️ Play Original', ...
    'Position',[50 110 180 40], ...
    'FontSize',12,...
    'Enable','off',...
    'ButtonPushedFcn',@(btn,event)playOriginalCallback());

playDenoisedBtn = uibutton(fig,'Text','▶️ Play Denoised', ...
    'Position',[270 110 180 40], ...
    'FontSize',12,...
    'Enable','off',...
    'ButtonPushedFcn',@(btn,event)playDenoisedCallback());

% Status text
statusText = uilabel(fig,'Text','Ready to record','Position',[50 60 400 30],...
    'FontSize',13,'HorizontalAlignment','center');

% Temporary files and folders
baseDir = scriptDir;
recordedFile = fullfile(baseDir, "temp_recording.wav");
denoisedFile = '';
preprocessedFolder = fullfile(baseDir, 'TEST-PRE');
modelOutputFolder = fullfile(baseDir, 'TEST-MODEL');
postprocessedFolder = fullfile(baseDir, 'TEST-POST');

if ~exist(preprocessedFolder,'dir'); mkdir(preprocessedFolder); end
if ~exist(modelOutputFolder,'dir'); mkdir(modelOutputFolder); end
if ~exist(postprocessedFolder,'dir'); mkdir(postprocessedFolder); end

%% ------------------- RECORD CALLBACK -------------------
    function recordCallback()
        if isvalid(recordBtn); recordBtn.Enable = 'off'; end
        duration = durationDropdown.Value;
        if isvalid(statusText); statusText.Text = sprintf("Recording for %d seconds...", duration); end
        drawnow;
        
        fs = 48000;
        recObj = audiorecorder(fs,16,1);
        recordblocking(recObj, duration);
        y = getaudiodata(recObj);
        audiowrite(recordedFile, y, fs);
        
        if isvalid(statusText); statusText.Text = sprintf("Recording saved! (%d sec)", duration); end
        if isvalid(playOriginalBtn); playOriginalBtn.Enable = 'on'; end
        if isvalid(recordBtn); recordBtn.Enable = 'on'; end
    end

%% ------------------- DENOISE CALLBACK -------------------
    function denoiseCallback()
        try
            denoiseBtn.Enable = 'off';
            statusText.Text = "Preprocessing...";
            drawnow;

            if ~isfile(recordedFile)
                statusText.Text = "No recording found! Record first.";
                denoiseBtn.Enable = 'on';
                return;
            end

            if isempty(net)
                statusText.Text = "Error: Trained model not loaded! Run main_simple.m first.";
                denoiseBtn.Enable = 'on';
                return;
            end

            % ----------------- Preprocessing -----------------
            preprocessing_single_recording(recordedFile, preprocessedFolder);

            preprocessedFiles = dir(fullfile(preprocessedFolder,'*_STFT_ratio.mat'));
            if isempty(preprocessedFiles)
                statusText.Text = "Preprocessing failed!";
                denoiseBtn.Enable = 'on';
                return;
            end
            P = load(fullfile(preprocessedFolder, preprocessedFiles(end).name));

            % ----------------- Extract and Verify Data -----------------
            statusText.Text = "Running model prediction...";
            drawnow;

            mag = P.mag;       % [257 x totalFrames]
            phase = P.phase;   % [257 x totalFrames]
            
            % FIX: Ensure magnitude is real and non-negative
            if ~isreal(mag)
                warning('Magnitude contains complex values, taking absolute value');
                mag = abs(mag);
            end
            mag = real(mag);  % Force to real even if already real
            
            % Ensure phase is real (should be angles in radians)
            if ~isreal(phase)
                warning('Phase contains complex values, taking angle');
                phase = angle(phase);
            end
            phase = real(phase);  % Force to real
            
            numFeatures = size(mag,1);
            totalFrames = size(mag,2);

            % ----------------- Format input for network -----------------
            % Network has sequenceInputLayer(257) which expects:
            % Input: [257 x T] where each column is one time step
            % This matches our mag format: [257 x 372]
            
            fprintf('Preparing input for network...\n');
            fprintf('mag original: size=%s, isreal=%d\n', mat2str(size(mag)), isreal(mag));
            
            % Ensure it's real and single precision
            mag = real(single(mag));
            
            % Run prediction - pass mag directly as [257 x T]
            YPred = predict(net, mag);
            
            % YPred should be same size as input
            predictedMask = YPred;
            
            fprintf('Prediction complete! Mask size: %s\n', mat2str(size(predictedMask)));

            % ----------------- Reconstruct Audio -----------------
            statusText.Text = "Reconstructing audio...";
            drawnow;
            
            fprintf('Reconstructing audio...\n');
            
            % Ensure predicted mask is real and non-negative
            predictedMask = real(predictedMask);
            predictedMask = max(predictedMask, 0);  % Masks should be non-negative
            
            fprintf('predictedMask: isreal=%d, min=%.4f, max=%.4f\n', ...
                isreal(predictedMask), min(predictedMask(:)), max(predictedMask(:)));
            
            enhancedMag = mag .* predictedMask;
            
            % Ensure enhanced magnitude is real and non-negative
            enhancedMag = real(enhancedMag);
            enhancedMag = max(enhancedMag, 0);
            
            fprintf('enhancedMag: isreal=%d, min=%.4f, max=%.4f\n', ...
                isreal(enhancedMag), min(enhancedMag(:)), max(enhancedMag(:)));
            fprintf('phase: isreal=%d, min=%.4f, max=%.4f\n', ...
                isreal(phase), min(phase(:)), max(phase(:)));
            
            predictedComplex_half = enhancedMag .* exp(1j * phase);
            
            fprintf('predictedComplex_half: isreal=%d, size=%s\n', ...
                isreal(predictedComplex_half), mat2str(size(predictedComplex_half)));

            % ISTFT parameters
            windowLength = 512;
            win = hamming(windowLength);
            overlap = round(0.75*windowLength);
            fftLength = windowLength;
            fs = 16000;
            
            fprintf('Calling istft...\n');

            % Reconstruct time-domain audio (Compatible with MATLAB R2024b and earlier)
            try
                % R2024b native 257-bin onesided ISTFT
                enhancedAudio = istft(predictedComplex_half, fs, ...
                                      'Window', win, ...
                                      'OverlapLength', overlap, ...
                                      'FFTLength', fftLength, ...
                                      'FrequencyRange', 'onesided');
            catch
                % Fallback for legacy full-spectrum ISTFT
                enhancedSTFT_full = [predictedComplex_half;
                                     conj(flipud(predictedComplex_half(2:end-1,:)))];
                enhancedAudio = istft(enhancedSTFT_full, ...
                                      'Window', win, ...
                                      'OverlapLength', overlap, ...
                                      'FFTLength', fftLength);
            end
            
            % Force to real (istft can return small imaginary components due to numerical errors)
            enhancedAudio = real(enhancedAudio);
            
            % Normalize
            enhancedAudio = enhancedAudio ./ max(abs(enhancedAudio)+1e-6);
            
            fprintf('enhancedAudio: isreal=%d, length=%d\n', ...
                isreal(enhancedAudio), length(enhancedAudio));

            % Save denoised audio
            denoisedFile = fullfile(postprocessedFolder, 'temp_recording_denoised.wav');
            audiowrite(denoisedFile, enhancedAudio, 16000);
            
            statusText.Text = "Denoising complete! Click 'Play' buttons.";
            playDenoisedBtn.Enable = 'on';
            denoiseBtn.Enable = 'on';

        catch ME
            statusText.Text = sprintf("Error: %s", ME.message);
            fprintf('Error in denoiseCallback: %s\n', ME.message);
            disp(ME.stack);
            denoiseBtn.Enable = 'on';
        end
    end

%% ------------------- PLAY CALLBACKS -------------------
    function playOriginalCallback()
        if isfile(recordedFile)
            if isvalid(statusText); statusText.Text = "Playing original recording..."; end
            drawnow;
            [y, fs] = audioread(recordedFile);
            sound(y, fs);
            pause(length(y)/fs + 0.5);
            if isvalid(statusText); statusText.Text = "Playback complete."; end
        else
            if isvalid(statusText); statusText.Text = "No recording found!"; end
        end
    end

    function playDenoisedCallback()
        if isfile(denoisedFile)
            if isvalid(statusText); statusText.Text = "Playing denoised audio..."; end
            drawnow;
            [y, fs] = audioread(denoisedFile);
            sound(y, fs);
            pause(length(y)/fs + 0.5);
            if isvalid(statusText); statusText.Text = "Playback complete."; end
        else
            if isvalid(statusText); statusText.Text = "No denoised audio found! Denoise first."; end
        end
    end

end
