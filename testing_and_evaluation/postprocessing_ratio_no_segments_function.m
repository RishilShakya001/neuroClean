function postprocessing_ratio_no_segments_function

fprintf('=== Postprocessing: Converting Model Outputs to Audio ===\n');

%%%% PARAMETERS %%%%
windowLength = 512;
win = hamming(windowLength);
overlap = round(0.75 * windowLength);
fftLength = windowLength;
fs = 16e3;
numFeatures = fftLength/2 + 1;
%%%%%%%%%%%%%%%%%%%%

model_output_folder = 'TEST-MODEL'; 
preprocessed_with_ratio = 'TEST-PRE';
postprocessed_folder = 'TEST-POST';
test_clean_folder = 'test_clean'; 
if ~exist(test_clean_folder, 'dir') && exist('../test_clean', 'dir')
    test_clean_folder = '../test_clean';
end
if ~exist(postprocessed_folder, 'dir')
    mkdir(postprocessed_folder);
end

predicted_files = dir(fullfile(model_output_folder, '*.mat'));
fprintf('Found %d model output files.\n', numel(predicted_files));

for i = 1:numel(predicted_files)

    % === Load model output ===
    filePath = fullfile(model_output_folder, predicted_files(i).name);
    data = load(filePath);  % contains YPred + predictors + testFilePath + cleanPhase_aligned

    % === Load matching preprocessed file ===
    preprocessedPath = fullfile(preprocessed_with_ratio, data.testFilePath);
    preprocessedData = load(preprocessedPath);

    % ===== CHECK: Print magnitudes =====
    % fprintf('\n--- File: %s ---\n', predicted_files(i).name);
    % fprintf('Max mixture magnitude: %.5f\n', max(preprocessedData.predictors(:)));
    % fprintf('Min mixture magnitude: %.5f\n', min(preprocessedData.predictors(:)));
    % fprintf('Mean mixture magnitude: %.5f\n', mean(preprocessedData.predictors(:)));

    % === Extract needed fields ===
    mixtureMag = preprocessedData.predictors;
    mixedPhase = preprocessedData.combinedPhase_aligned;
    cleanPhase = preprocessedData.cleanPhase_aligned;
    ratioMask = data.model_prediction;                            
    ratioMask = max(0, min(ratioMask, 1));  % clip to [0, 1]
    
    % ===== CHECK: Print model mask values =====
    % fprintf('Max predicted ratio mask: %.5f\n', max(ratioMask(:)));
    % fprintf('Min predicted ratio mask: %.5f\n', min(ratioMask(:)));
    % fprintf('Mean predicted ratio mask: %.5f\n', mean(ratioMask(:)));
    
    % === Ensure same number of frames ===
    minFrames = min([size(mixtureMag,2), size(ratioMask,2), size(mixedPhase,2)]);
    mixtureMag = mixtureMag(:,1:minFrames);
    ratioMask  = ratioMask(:,1:minFrames);
    cleanPhase = cleanPhase(:,1:minFrames);

    % === Apply the predicted mask ===
    estimatedCleanMag = mixtureMag .* ratioMask;

    % ===== CHECK: Print estimated magnitude =====
    % fprintf('Max estimated clean magnitude: %.5f\n', max(estimatedCleanMag(:)));
    % fprintf('Min estimated clean magnitude: %.5f\n', min(estimatedCleanMag(:)));
    % fprintf('Mean estimated clean magnitude: %.5f\n', mean(estimatedCleanMag(:)));


    % === Reconstruct complex STFT ===
    predictedComplex_half = estimatedCleanMag .* exp(1j * mixedPhase);

    % Full STFT
    cleanComplex = [predictedComplex_half;
                    conj(flipud(predictedComplex_half(2:end-1, :)))];

    % === Inverse STFT ===
    denoisedAudio = istft(cleanComplex, ...
        'Window', win, ...
        'OverlapLength', overlap, ...
        'FFTLength', fftLength);
    denoisedAudio = real(denoisedAudio);

    % === Load corresponding clean audio ===
    % Extract base filename
    [~, baseName, ~] = fileparts(data.testFilePath);
    
    % Remove the '_STFT_ratio' suffix to get the original combined name
    baseName = strrep(baseName, '_STFT_ratio', '');
    
    % Parse the "_with_" pattern to extract clean name
    parts = split(baseName, '_with_');
if length(parts) < 2
    warning('Cannot parse clean filename from: %s. Skipping RMS scaling.', baseName);
    cleanName = baseName;  % fallback
else
    cleanName = parts{1};  % e.g., "p250_083_mic2_seg1"
end

cleanFilePath = fullfile(test_clean_folder, [cleanName '.wav']);
    if exist(cleanFilePath, 'file')
        [clean_audio, fs_clean] = audioread(cleanFilePath);
        if fs_clean ~= fs
            clean_audio = resample(clean_audio, fs, fs_clean);
        end
        % Match lengths
        minLen = min(length(clean_audio), length(denoisedAudio));
        clean_audio = clean_audio(1:minLen);
        denoisedAudio = denoisedAudio(1:minLen);

        % Scale denoised audio to match clean audio RMS
        denoisedAudio = denoisedAudio * rms(clean_audio) / (rms(denoisedAudio) + eps);
    else
        warning('Clean file not found: %s. Skipping RMS scaling.', cleanFilePath);
    end

    % === Save output ===
    outputPath = fullfile(postprocessed_folder, [baseName '_Predicted.wav']);
    audiowrite(outputPath, denoisedAudio, fs);

end

fprintf('\n=== Postprocessing Complete ===\n');

end

