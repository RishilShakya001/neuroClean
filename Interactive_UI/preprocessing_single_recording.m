function preprocessing_single_recording(recordedFile, preprocessedFolder)
% Preprocess a single recorded audio file for CNN+LSTM
%%%% PARAMETERS %%%%
windowLength = 512;
win = hamming(windowLength);
overlap = round(0.75 * windowLength);
fftLength = 512;  % FIXED: Explicitly set to 512
fs = 16e3; % target sample rate
numFeatures = fftLength/2 + 1;  % This will be 257
%%%%%%%%%%%%%%%%%%%%

% Convert inputs to char arrays
recordedFile = char(recordedFile);
preprocessedFolder = char(preprocessedFolder);

% Ensure output folder exists
if ~exist(preprocessedFolder, 'dir')
    mkdir(preprocessedFolder);
end

% Read audio
[noisyAudio, fsRec] = audioread(recordedFile);

% IMPORTANT: Resample FIRST before any processing
if fsRec ~= fs
    noisyAudio = resample(noisyAudio, fs, fsRec);
    fprintf('Resampled from %d Hz to %d Hz\n', fsRec, fs);
end

% Ensure mono
if size(noisyAudio, 2) > 1
    noisyAudio = mean(noisyAudio, 2);
end

% Compute STFT with exact parameters
S = stft(noisyAudio, 'Window', win, 'OverlapLength', overlap, 'FFTLength', fftLength);

% Extract only the positive frequencies (first 257 rows)
S = S(1:numFeatures, :);

% Magnitude and phase
mag = abs(S);
phase = angle(S);

% Debug: print dimensions
fprintf('STFT size: %d x %d\n', size(S, 1), size(S, 2));
fprintf('Magnitude size: %d x %d (should be 257 x T)\n', size(mag, 1), size(mag, 2));

% Dummy IRM (just ones for a single recording)
IRM = ones(size(mag), 'single');

% Extract filename
[~, baseName, ~] = fileparts(recordedFile);

% Create output paths
outputFile = [preprocessedFolder filesep baseName '_STFT_ratio.mat'];
debugFile = [preprocessedFolder filesep baseName '_STFT_debug.mat'];

fprintf('Saving to: %s\n', outputFile);

% Save files
save(outputFile, 'mag', 'IRM', 'phase', 'fs');
save(debugFile, 'mag', 'IRM', 'phase');

fprintf('Preprocessing complete! Saved with %d features\n', size(mag, 1));
end
