function combine_voice_with_noise(voice_folder, noise_folder, output_voice_noise, target_snrs)
%%% combine_voice_with_noise.m
% DESCRIPTION: Takes clean speech WAV files and noise WAV files, mixes them
% together at specified Signal-to-Noise Ratios (SNR), and saves the resulting
% combined audio files to an output folder. Can be run directly as a script
% (uses default folders) or called as a function with optional parameters.

% Determine script directory to ensure reliable default paths regardless of current working directory
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

% --- Input folders ---
% Accept 'speech_folder' as an alias for 'voice_folder' for pipeline compatibility
if (~exist('voice_folder', 'var') || isempty(voice_folder)) && exist('speech_folder', 'var') && ~isempty(speech_folder)
    voice_folder = speech_folder;
end
if ~exist('voice_folder', 'var') || isempty(voice_folder)
    voice_folder = fullfile(scriptDir, 'train_clean');
end

if ~exist('noise_folder', 'var') || isempty(noise_folder)
    noise_folder = fullfile(scriptDir, 'train_noise');
end

% --- Output folder ---
base_output = scriptDir;
if exist('output_voice_noise', 'var') && ~isempty(output_voice_noise)
    % already defined by caller
    base_output = fileparts(output_voice_noise);
    if isempty(base_output); base_output = scriptDir; end
elseif exist('combined_folder', 'var') && ~isempty(combined_folder)
    output_voice_noise = combined_folder;
    base_output = fileparts(output_voice_noise);
    if isempty(base_output); base_output = scriptDir; end
else
    output_voice_noise = fullfile(base_output, 'combined_audio_output');
end

% Ensure output directory exists
if ~exist(output_voice_noise, 'dir')
    mkdir(output_voice_noise);
end

% --- Log file setup ---
log_file = fullfile(base_output, 'combine_voice_with_noise_log.txt');
diary off; % Ensure previous diary session is closed
try
    if exist(log_file, 'file')
        delete(log_file);
    end
catch
    % In case file is locked by another process
end
diary(log_file);
diary on;

fprintf('--- VCTK Voice + Noise Mixing Starting...\n');

try
    % --- Parameters ---
    if ~exist('target_snrs', 'var') || isempty(target_snrs)
        target_snrs = [-5, 0, 5, 10]; % Balanced range of SNR levels for training data balance
    end

    % Locate speech and noise WAV files
    voice_files = dir(fullfile(voice_folder, '*.wav'));
    if isempty(voice_files)
        voice_files = dir(fullfile(voice_folder, '*.WAV'));
    end
    if ~isempty(voice_files)
        voice_files = voice_files(~[voice_files.isdir]);
    end

    noise_files = dir(fullfile(noise_folder, '*.wav'));
    if isempty(noise_files)
        noise_files = dir(fullfile(noise_folder, '*.WAV'));
    end
    if ~isempty(noise_files)
        noise_files = noise_files(~[noise_files.isdir]);
    end

    num_voice_files = length(voice_files);
    num_noise_files = length(noise_files);

    fprintf('Found %d voice files and %d noise files.\n', num_voice_files, num_noise_files);

    % Sample audio generator parameters (48 kHz native to VCTK)
    fs_sample = 48000;
    t_sample = (0:1/fs_sample:3.0)'; % 3 second duration

    % Generate synthetic voice files if none exist
    if num_voice_files == 0
        fprintf('No voice files found in "%s".\nGenerating sample synthetic clean speech files...\n', voice_folder);
        if ~exist(voice_folder, 'dir'); mkdir(voice_folder); end
        
        for k = 1:5
            f0 = 130 + k*20;
            env = sin(pi * t_sample / 3.0);
            speech = (0.5*sin(2*pi*f0*t_sample) + 0.3*sin(2*pi*f0*2*t_sample) + 0.2*sin(2*pi*1400*t_sample)) .* env;
            speech = speech / (max(abs(speech)) + eps);
            audiowrite(fullfile(voice_folder, sprintf('sample_clean_speech_%02d.wav', k)), speech, fs_sample);
        end

        voice_files = dir(fullfile(voice_folder, '*.wav'));
        voice_files = voice_files(~[voice_files.isdir]);
        num_voice_files = length(voice_files);
    end

    % Generate synthetic noise files if none exist
    if num_noise_files == 0
        fprintf('No noise files found in "%s".\nGenerating sample synthetic noise files...\n', noise_folder);
        if ~exist(noise_folder, 'dir'); mkdir(noise_folder); end
        
        noiseTypes = {'cafe', 'engine', 'white', 'street', 'keyboard'};
        for k = 1:5
            w = randn(length(t_sample), 1);
            if k == 1
                nSignal = filter(1, [1, -0.95], w) * 0.1; % Pink/chatter noise
            elseif k == 2
                nSignal = 0.3*sin(2*pi*60*t_sample) + 0.15*randn(length(t_sample), 1); % Engine hum
            else
                nSignal = w * 0.15; % White noise
            end
            nSignal = nSignal / (max(abs(nSignal)) + eps);
            audiowrite(fullfile(noise_folder, sprintf('sample_%s_noise_%02d.wav', noiseTypes{k}, k)), nSignal, fs_sample);
        end

        noise_files = dir(fullfile(noise_folder, '*.wav'));
        noise_files = noise_files(~[noise_files.isdir]);
        num_noise_files = length(noise_files);
    end

    if num_voice_files == 0 || num_noise_files == 0
        warning('Unable to proceed: missing voice or noise files (voice: %d, noise: %d).', num_voice_files, num_noise_files);
        diary off;
        return;
    end

    rng(0); % Reproducibility

    % --- Main mixing loop ---
    processed_count = 0;
    for i = 1:num_voice_files
        % Select target SNR (cycled)
        target_snr_db = target_snrs(mod(i-1, length(target_snrs)) + 1);

        % Load clean speech
        voice_file = voice_files(i).name;
        voice_path = fullfile(voice_folder, voice_file);
        try
            [voice, fs_v] = audioread(voice_path);
        catch err
            warning('Failed reading voice file %s: %s. Skipping.', voice_path, err.message);
            continue;
        end

        % Clean NaN / Inf and enforce mono column vector
        voice(isnan(voice) | isinf(voice)) = 0;
        if size(voice, 2) > 1
            voice = mean(voice, 2);
        end
        voice = voice(:);

        if isempty(voice)
            warning('Voice file %s is empty. Skipping.', voice_file);
            continue;
        end

        % Select noise (cycled)
        noise_idx = mod(i-1, num_noise_files) + 1;
        noise_file = noise_files(noise_idx).name;
        noise_path = fullfile(noise_folder, noise_file);
        try
            [noise_full, fs_n] = audioread(noise_path);
        catch err
            warning('Failed reading noise file %s: %s. Skipping.', noise_path, err.message);
            continue;
        end

        % Clean NaN / Inf and enforce mono column vector
        noise_full(isnan(noise_full) | isinf(noise_full)) = 0;
        if size(noise_full, 2) > 1
            noise_full = mean(noise_full, 2);
        end
        noise_full = noise_full(:);

        if isempty(noise_full)
            warning('Noise file %s is empty. Skipping.', noise_file);
            continue;
        end

        % Resample noise if sample rates differ
        if fs_n ~= fs_v
            try
                noise_full = resample(noise_full, fs_v, fs_n);
            catch
                % Fallback interpolation if Signal Processing Toolbox resample is unavailable
                t_orig = (0:length(noise_full)-1)' / fs_n;
                t_target = (0:1/fs_v:t_orig(end))';
                noise_full = interp1(t_orig, noise_full, t_target, 'linear', 'extrap');
            end
        end

        % Match lengths (trim or repeat)
        len_v = length(voice);
        len_n = length(noise_full);
        if len_n > len_v
            start_idx = randi(len_n - len_v + 1);
            noise = noise_full(start_idx:start_idx+len_v-1);
        elseif len_n < len_v
            repeats = ceil(len_v / len_n);
            noise = repmat(noise_full, repeats, 1);
            noise = noise(1:len_v);
        else
            noise = noise_full;
        end

        % Scale noise to target SNR
        voice_power = mean(voice.^2);
        noise_power = mean(noise.^2);
        desired_noise_power = voice_power / (10^(target_snr_db / 10));
        noise_scaled = noise * sqrt(desired_noise_power / (noise_power + eps));

        % Mix signals
        voice_noise = voice + noise_scaled;

        % Normalize to 0.99 peak to strictly avoid clipping on WAV export
        max_peak = max(abs(voice_noise));
        if max_peak > 0
            voice_noise = (voice_noise / max_peak) * 0.99;
        end

        % Output filename: preserve original voice name + "_with_" + noise name
        [~, voice_name, ~] = fileparts(voice_file);
        [~, noise_name, ~] = fileparts(noise_file);
        out_name = sprintf('%s_with_%s.wav', voice_name, noise_name);
        out_path = fullfile(output_voice_noise, out_name);

        try
            audiowrite(out_path, voice_noise, fs_v);
            processed_count = processed_count + 1;
        catch err
            warning('Failed writing audio file %s: %s', out_path, err.message);
            continue;
        end

        % Log progress periodically
        if mod(i, 500) == 0 || i == num_voice_files
            fprintf('Processed %d/%d files (%.1f%%)\n', i, num_voice_files, (i/num_voice_files)*100);
        end
    end

    fprintf('Successfully generated %d combined audio files in "%s".\n', processed_count, output_voice_noise);
    disp('All voice+noise files created successfully!');
    diary off;

catch ME
    diary off;
    rethrow(ME);
end

end


