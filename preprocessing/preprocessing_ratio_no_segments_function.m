function preprocessing_ratio_no_segments_function(combinedFolder, speechFolder, noiseFolder, preprocessedFolder)

% This code processes full STFT sequences for CNN+LSTM (no segmentation)

%%%% PARAMETERS %%%

% size of signal we examine at a time
windowLength = 512;
% hamming window to avoid spectral leakage
win = hamming(windowLength);
% overlap between consecutive windows
overlap = round(0.75*windowLength);
% length of FFT
fftLength = windowLength;
% sampling rate of original input - 48 kHz
inputFs = 48e3;
% sampling rate of target downsampled input - 16 kHz
fs = 16e3;
% calculates the number of frequency bins in the STFT
numFeatures = fftLength/2 + 1;

%%%%%%%%%%%%%%%%%%%%

% create downsampling object
src = dsp.SampleRateConverter(InputSampleRate=inputFs,OutputSampleRate=fs, ...
    Bandwidth=7920);

% get list of audio files from input combined folder
combinedFiles  = dir(fullfile(combinedFolder, '*.wav'));

% output folder
if ~exist('preprocessedFolder', 'var') || isempty(preprocessedFolder)
    preprocessedFolder = 'TEST-PRE';
end

if ~exist(preprocessedFolder, 'dir')
    mkdir(preprocessedFolder);
end

debugFolder = fullfile(preprocessedFolder, 'debug_visualizations');
if ~exist(debugFolder, 'dir')
    mkdir(debugFolder);
end

for i = 1:numel(combinedFiles)
    [~, combinedName, ~] = fileparts(combinedFiles(i).name);
    fprintf('preprocessing file %s\n', combinedName);
    parts = split(combinedName, '_with_');
    cleanName = parts{1};

    % read audio
    combinedFile = fullfile(combinedFolder, [combinedName '.wav']);
    cleanFile = fullfile(speechFolder, [cleanName '.wav']);

    [combinedAudio, ~] = audioread(combinedFile);
    [cleanAudio, ~] = audioread(cleanFile);

    % Enforce mono
    if size(combinedAudio, 2) > 1
        combinedAudio = mean(combinedAudio, 2);
    end
    if size(cleanAudio, 2) > 1
        cleanAudio = mean(cleanAudio, 2);
    end

    % downsample
    combinedAudio = src(combinedAudio);
    cleanAudio = src(cleanAudio);

    % match clean and combined audio in case of small alignment issues
    minLen = min([length(combinedAudio), length(cleanAudio)]);
    combinedAudio = combinedAudio(1:minLen);
    cleanAudio = cleanAudio(1:minLen);

    % Scale-align clean audio to the mixture
    alpha = (combinedAudio' * cleanAudio) / (cleanAudio' * cleanAudio + eps);
    cleanAudio_scaled = alpha * cleanAudio;

    % The noise in the mixture is the residual
    noisyAudio = combinedAudio - cleanAudio_scaled;

    % compute STFTs
    cleanSTFT = stft(cleanAudio_scaled, 'Window', win, 'OverlapLength', overlap, 'FFTLength', fftLength);
    noisySTFT = stft(noisyAudio, 'Window', win, 'OverlapLength', overlap, 'FFTLength', fftLength);
    combinedSTFT = stft(combinedAudio, 'Window', win, 'OverlapLength', overlap, 'FFTLength', fftLength);

    cleanPhase = angle(cleanSTFT(1:numFeatures,:));       % for reconstruction
    combinedPhase = angle(combinedSTFT(1:numFeatures,:)); % for reconstruction

    % magnitude only
    cleanSTFT = abs(cleanSTFT(1:numFeatures,:));
    noisySTFT = abs(noisySTFT(1:numFeatures,:));
    combinedSTFT = abs(combinedSTFT(1:numFeatures,:));

    % free memory
    clear cleanAudio noisyAudio combinedAudio cleanAudio_scaled

    % ideal ratio mask
    IRM = cleanSTFT ./ (cleanSTFT + noisySTFT + eps);
    IRM = min(1, max(0, IRM)); % clip

    % save first 10 for visualization
    if i <= 10
        visFile = fullfile(debugFolder, [combinedName '_STFT_debug.mat']);
        save(visFile, 'cleanSTFT', 'noisySTFT', 'combinedSTFT', 'IRM');
    end

    % full sequence predictors and targets
    predictors = single(combinedSTFT);  % [numFeatures × numFrames]
    targets = single(IRM);               % [numFeatures × numFrames]

    % aligned phases
    cleanPhase_aligned = single(cleanPhase);
    combinedPhase_aligned = single(combinedPhase);
    cleanSTFT_mag = single(cleanSTFT);

    % save
    testFilePath = [combinedName '_STFT_ratio.mat'];
    outputFile = fullfile(preprocessedFolder, [combinedName '_STFT_ratio.mat']);
    save(outputFile, 'predictors', 'targets', 'fs', 'combinedPhase_aligned', ...
        'cleanPhase_aligned', 'cleanSTFT_mag', 'numFeatures', 'testFilePath');

    reset(src);
end

end
