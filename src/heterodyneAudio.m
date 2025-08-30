function [heterodynedAudio, fs] = heterodyneAudio(audioFilename, carrierFreq, channel)
% HETERODYNEAUDIO - Perform heterodyne processing on an audio file.
%
%   [heterodynedAudio, fs] = heterodyneAudio(audioFilename, carrierFreq)
%   [heterodynedAudio, fs] = heterodyneAudio(audioFilename, carrierFreq, channel)
%
%   Inputs:
%       audioFilename - Path to the audio file (e.g., .wav)
%       carrierFreq   - Carrier frequency for heterodyning (Hz)
%       channel       - Optional. Channel number (1 for left, 2 for right, default is 1)
%
%   Outputs:
%       heterodynedAudio - The heterodyned audio signal (time domain)
%       fs               - Sampling frequency of the audio file

    if nargin < 3
        channel = 1; % Default to left channel
    end

    % Read audio
    [audioData, fs] = audioread(audioFilename); 

    if size(audioData, 2) < channel
        error('Audio file does not have the specified channel (%d).', channel);
    end

    audioSignal = audioData(:, channel);
    rms_audioSignal = rms(audioSignal);
    audioSignal = bandpassFilter(audioSignal, 1e3, 0.45*fs, 4, fs);
    rms_audioSignal_postFilter = rms(audioSignal);
    audioSignal = audioSignal * (rms_audioSignal/rms_audioSignal_postFilter);


    % % Debug
    % disp(['Audio Data RMS ' num2str(rms_audioSignal)]);
    % disp(['Bandpassed Audio Data RMS ' num2str(rms_audioSignal_postFilter)]);
    % disp(['Restored Audio Data RMS ' num2str(rms(audioSignal))]);

    % Create a cosine wave at the carrier frequency
    t = (0:length(audioSignal)-1)' / fs;
    carrier = cos(2 * pi * carrierFreq * t);

    % Heterodyne: Mix signal with carrier
    heterodynedAudio = audioSignal .* carrier;

    % Optional: Apply a low-pass filter to remove high-frequency artifacts
    % Nyquist = fs/2. Let3s cut off at 30 kHz or lower depending on fs.
    cutoffFreq = min(30000, fs/2 - 1000);
    if cutoffFreq < fs/2
        d = designfilt('lowpassfir', 'PassbandFrequency', cutoffFreq * 0.8, ...
                       'StopbandFrequency', cutoffFreq, 'SampleRate', fs);
        heterodynedAudio = filter(d, heterodynedAudio);
        rms_hetAudio = rms(heterodynedAudio);
        heterodynedAudio = heterodynedAudio * (rms_audioSignal/rms_hetAudio);
    end
    
    % % Debug
    %  disp(['Heterodyned filtered Audio Data RMS ' num2str(rms_hetAudio)]);
    %  disp(['Heterodyned restored Audio Data RMS ' num2str(rms(heterodynedAudio))]);
end