import React, { useState, useEffect, useRef } from 'react';
import { 
  Mic, MicOff, Play, Pause, Volume2, Sparkles, Sliders, RefreshCw, 
  CheckCircle2, Download, Zap, FileAudio, ArrowRight, ShieldCheck, Activity
} from 'lucide-react';
import confetti from 'canvas-confetti';

import {
  generateVoiceBuffer,
  generateNoiseBuffer,
  mixAudioBuffers,
  denoiseAudioBuffer,
  resampleTo16k,
  drawWaveform,
  drawSpectrogram,
  drawPlaceholderCanvas
} from '../utils/audioProcessor';

export default function InteractiveStudio() {
  const [audioCtx, setAudioCtx] = useState(null);
  const [selectedNoiseType, setSelectedNoiseType] = useState('cafe');
  const [targetSNR, setTargetSNR] = useState(-3.5);
  const [suppressionStrength, setSuppressionStrength] = useState(0.85);
  const [audioSourceType, setAudioSourceType] = useState('preset'); // 'preset' | 'mic' | 'file'
  const [rawVoiceBuffer, setRawVoiceBuffer] = useState(null);

  // Audio State
  const [noisyBuffer, setNoisyBuffer] = useState(null);
  const [denoisedBuffer, setDenoisedBuffer] = useState(null);
  const [metrics, setMetrics] = useState(null);

  // Recording State
  const [isRecording, setIsRecording] = useState(false);
  const [recordTime, setRecordTime] = useState(0);
  const mediaRecorderRef = useRef(null);
  const mediaStreamRef = useRef(null);
  const audioChunksRef = useRef([]);

  // Processing State
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const timeoutsRef = useRef([]);

  // Playback State
  const [isPlayingNoisy, setIsPlayingNoisy] = useState(false);
  const [isPlayingClean, setIsPlayingClean] = useState(false);
  const [isPlayingRaw, setIsPlayingRaw] = useState(false);
  const activeSourceRef = useRef(null);

  // Canvas Refs
  const canvasNoisyWaveRef = useRef(null);
  const canvasCleanWaveRef = useRef(null);
  const canvasNoisySpecRef = useRef(null);
  const canvasCleanSpecRef = useRef(null);

  // Initialize Web Audio Context
  useEffect(() => {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    setAudioCtx(ctx);
    return () => {
      ctx.close();
      timeoutsRef.current.forEach(clearTimeout);
    };
  }, []);

  // Master Audio Synthesis Effect: keeps recorded/uploaded voice active across noise changes
  useEffect(() => {
    if (!audioCtx) return;
    stopAudioPlayback();

    let activeVoice = null;
    if ((audioSourceType === 'mic' || audioSourceType === 'file') && rawVoiceBuffer) {
      activeVoice = rawVoiceBuffer;
    } else {
      activeVoice = generateVoiceBuffer(audioCtx, 3.5);
    }

    if (!activeVoice) return;

    if (selectedNoiseType === 'none') {
      setNoisyBuffer(activeVoice);
    } else {
      const noiseBuf = generateNoiseBuffer(audioCtx, selectedNoiseType, activeVoice.duration, activeVoice.sampleRate);
      const { mixedBuffer } = mixAudioBuffers(audioCtx, activeVoice, noiseBuf, targetSNR);
      setNoisyBuffer(mixedBuffer);
    }

    setDenoisedBuffer(null);
    setMetrics(null);
  }, [audioCtx, selectedNoiseType, targetSNR, audioSourceType, rawVoiceBuffer]);

  // Clean Recording Timer Effect
  useEffect(() => {
    let timer = null;
    if (isRecording) {
      setRecordTime(0);
      timer = setInterval(() => {
        setRecordTime((prev) => {
          if (prev >= 9) {
            stopRecording();
            return 10;
          }
          return prev + 1;
        });
      }, 1000);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [isRecording]);

  // Redraw canvases when buffers change
  useEffect(() => {
    const handle = requestAnimationFrame(() => {
      if (noisyBuffer && canvasNoisyWaveRef.current && canvasNoisySpecRef.current) {
        drawWaveform(canvasNoisyWaveRef.current, noisyBuffer, '#ef4444');
        drawSpectrogram(canvasNoisySpecRef.current, noisyBuffer, false);
      }
      if (denoisedBuffer && canvasCleanWaveRef.current && canvasCleanSpecRef.current) {
        drawWaveform(canvasCleanWaveRef.current, denoisedBuffer, '#00d2ff');
        drawSpectrogram(canvasCleanSpecRef.current, denoisedBuffer, true);
      } else if (!denoisedBuffer && canvasCleanWaveRef.current && canvasCleanSpecRef.current) {
        drawPlaceholderCanvas(canvasCleanWaveRef.current, '#00d2ff', 'Awaiting Suppress Background Noise Execution');
        drawPlaceholderCanvas(canvasCleanSpecRef.current, '#00d2ff', 'Spectrogram Heatmap Will Render Here');
      }
    });
    return () => cancelAnimationFrame(handle);
  }, [noisyBuffer, denoisedBuffer]);

  // Helper to decode audio ArrayBuffer robustly across all browser engines
  const decodeAudioArrayBuffer = async (ctx, arrayBuffer) => {
    if (ctx.state === 'suspended') {
      await ctx.resume();
    }
    return new Promise((resolve, reject) => {
      try {
        const copy = arrayBuffer.slice(0);
        const promise = ctx.decodeAudioData(
          copy,
          (decoded) => resolve(decoded),
          (err) => reject(err)
        );
        if (promise && typeof promise.then === 'function') {
          promise.then(resolve).catch(reject);
        }
      } catch (e) {
        reject(e);
      }
    });
  };

  // Start Microphone Recording
  const startRecording = async () => {
    if (isRecording || !audioCtx) return;
    stopAudioPlayback();

    try {
      if (audioCtx.state === 'suspended') {
        await audioCtx.resume();
      }

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;

      // Determine best supported MIME type
      let mimeType = '';
      if (typeof MediaRecorder !== 'undefined') {
        if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) mimeType = 'audio/webm;codecs=opus';
        else if (MediaRecorder.isTypeSupported('audio/webm')) mimeType = 'audio/webm';
        else if (MediaRecorder.isTypeSupported('audio/mp4')) mimeType = 'audio/mp4';
      }

      const options = mimeType ? { mimeType } : {};
      const mediaRecorder = new MediaRecorder(stream, options);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = async () => {
        // Wait 100ms for final data chunks to flush into audioChunksRef
        await new Promise((resolve) => setTimeout(resolve, 100));

        // Release microphone stream tracks
        if (mediaStreamRef.current) {
          mediaStreamRef.current.getTracks().forEach((track) => track.stop());
          mediaStreamRef.current = null;
        }

        if (!audioChunksRef.current || audioChunksRef.current.length === 0) {
          alert('No microphone audio captured. Please ensure your microphone is enabled and speak clearly while recording.');
          return;
        }

        try {
          const finalMime = mediaRecorder.mimeType || mimeType || 'audio/webm';
          const audioBlob = new Blob(audioChunksRef.current, { type: finalMime });
          const arrayBuffer = await audioBlob.arrayBuffer();
          const decoded = await decodeAudioArrayBuffer(audioCtx, arrayBuffer);
          const resampled = await resampleTo16k(decoded);

          // Normalize recorded mic audio peak amplitude to 0.7 for clear visualizer and audibility
          const channel = resampled.getChannelData(0);
          let maxAmp = 0;
          for (let i = 0; i < channel.length; i++) {
            const abs = Math.abs(channel[i]);
            if (abs > maxAmp) maxAmp = abs;
          }
          if (maxAmp > 0.005) {
            const gain = 0.7 / maxAmp;
            for (let i = 0; i < channel.length; i++) {
              channel[i] *= gain;
            }
          }

          setRawVoiceBuffer(resampled);
          setAudioSourceType('mic');
        } catch (decodeErr) {
          console.error('Microphone audio decoding error:', decodeErr);
          alert('Could not decode microphone recording. Please ensure your browser microphone permissions are enabled.');
        }
      };

      // Start recording with 100ms timeslice to ensure continuous chunk collection
      mediaRecorder.start(100);
      setIsRecording(true);

    } catch (err) {
      console.error('Microphone access error:', err);
      alert('Microphone access failed or was denied. Please allow microphone permissions in your browser address bar.');
    }
  };

  // Stop Microphone Recording
  const stopRecording = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }
    setIsRecording(false);
  };

  // Noise Profile Selection Handler (Preserves active voice source!)
  const handleSelectNoise = (noiseId, snrVal) => {
    setSelectedNoiseType(noiseId);
    if (snrVal !== undefined) setTargetSNR(snrVal);
  };

  // Switch back to synthetic demo voice
  const handleSwitchToSynthetic = () => {
    setAudioSourceType('preset');
  };

  // Custom File Upload
  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file || !audioCtx) return;
    stopAudioPlayback();
    try {
      const arrayBuffer = await file.arrayBuffer();
      const decoded = await decodeAudioArrayBuffer(audioCtx, arrayBuffer);
      const resampled = await resampleTo16k(decoded);

      // Normalize peak amplitude to 0.7 for consistent visualizer and audio volume
      const channel = resampled.getChannelData(0);
      let maxAmp = 0;
      for (let i = 0; i < channel.length; i++) {
        const abs = Math.abs(channel[i]);
        if (abs > maxAmp) maxAmp = abs;
      }
      if (maxAmp > 0.005) {
        const gain = 0.7 / maxAmp;
        for (let i = 0; i < channel.length; i++) {
          channel[i] *= gain;
        }
      }

      setRawVoiceBuffer(resampled);
      setAudioSourceType('file');
    } catch (err) {
      console.error('File decode error:', err);
      alert('Error parsing audio file. Please select a valid WAV, MP3, or M4A audio file.');
    }
  };

  // Run Denoising Engine
  const runDenoisingEngine = () => {
    if (!noisyBuffer || !audioCtx || isProcessing) return;
    stopAudioPlayback();
    setIsProcessing(true);
    setCurrentStep(1);

    timeoutsRef.current.forEach(clearTimeout);
    timeoutsRef.current = [];

    const steps = [
      { step: 1, delay: 400 },
      { step: 2, delay: 800 },
      { step: 3, delay: 1200 },
      { step: 4, delay: 1500 },
    ];

    steps.forEach(({ step, delay }) => {
      const t = setTimeout(() => setCurrentStep(step), delay);
      timeoutsRef.current.push(t);
    });

    const finalT = setTimeout(() => {
      const { denoisedBuffer: resultBuf, metrics: resultMetrics } = denoiseAudioBuffer(
        audioCtx,
        noisyBuffer,
        suppressionStrength
      );
      setDenoisedBuffer(resultBuf);
      setMetrics(resultMetrics);
      setIsProcessing(false);
      setCurrentStep(0);

      confetti({
        particleCount: 50,
        spread: 60,
        origin: { y: 0.7 }
      });
    }, 1800);

    timeoutsRef.current.push(finalT);
  };


  // Playback handlers with Play/Stop toggle
  const togglePlayRaw = () => {
    if (isPlayingRaw) {
      stopAudioPlayback();
    } else {
      playBuffer(rawVoiceBuffer, 'raw');
    }
  };

  const togglePlayNoisy = () => {
    if (isPlayingNoisy) {
      stopAudioPlayback();
    } else {
      playBuffer(noisyBuffer, 'noisy');
    }
  };

  const togglePlayClean = () => {
    if (isPlayingClean) {
      stopAudioPlayback();
    } else {
      playBuffer(denoisedBuffer, 'clean');
    }
  };

  const playBuffer = async (buffer, type) => {
    if (!audioCtx || !buffer) return;
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }
    stopAudioPlayback();

    const source = audioCtx.createBufferSource();
    source.buffer = buffer;
    source.connect(audioCtx.destination);

    source.onended = () => {
      setIsPlayingNoisy(false);
      setIsPlayingClean(false);
      setIsPlayingRaw(false);
    };

    source.start(0);
    activeSourceRef.current = source;

    if (type === 'noisy') setIsPlayingNoisy(true);
    if (type === 'clean') setIsPlayingClean(true);
    if (type === 'raw') setIsPlayingRaw(true);
  };

  const stopAudioPlayback = () => {
    if (activeSourceRef.current) {
      try { activeSourceRef.current.stop(); } catch (e) {}
      activeSourceRef.current = null;
    }
    setIsPlayingNoisy(false);
    setIsPlayingClean(false);
    setIsPlayingRaw(false);
  };

  // Download Denoised WAV file
  const downloadDenoisedWav = () => {
    if (!denoisedBuffer) return;
    const channelData = denoisedBuffer.getChannelData(0);
    const wavBlob = createWavBlob(channelData, 16000);
    const url = URL.createObjectURL(wavBlob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `NeuroClean_Denoised_Speech_${Date.now()}.wav`;
    a.click();
  };

  const createWavBlob = (samples, sampleRate) => {
    const buffer = new ArrayBuffer(44 + samples.length * 2);
    const view = new DataView(buffer);

    const writeString = (offset, string) => {
      for (let i = 0; i < string.length; i++) {
        view.setUint8(offset + i, string.charCodeAt(i));
      }
    };

    writeString(0, 'RIFF');
    view.setUint32(4, 36 + samples.length * 2, true);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, 1, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeString(36, 'data');
    view.setUint32(40, samples.length * 2, true);

    let offset = 44;
    for (let i = 0; i < samples.length; i++, offset += 2) {
      const s = Math.max(-1, Math.min(1, samples[i]));
      view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
    }
    return new Blob([buffer], { type: 'audio/wav' });
  };

  return (
    <div className="container" style={{ paddingBottom: '4rem' }}>
      
      {/* Hero Section */}
      <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.75rem' }}>
          Interactive Speech <span className="gradient-text">Denoising Studio</span>
        </h2>
        <p style={{ color: 'var(--text-muted)', maxWidth: '700px', margin: '0 auto', fontSize: '1rem' }}>
          Test the hybrid CNN-LSTM neural network. Record speech, select background noise environments, 
          and execute Short-Time Fourier Transform (STFT) Ideal Ratio Masking to isolate clean voice.
        </p>
      </div>

      {/* Control Panel Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        
        {/* Step 1: Input Source & Noise Layer Selection */}
        <div className="glass-panel" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '1.25rem' }}>
            <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'var(--primary-cyan)', color: '#000', fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.85rem' }}>1</div>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Choose Speech Voice & Noise</h3>
          </div>

          {/* Section 1A: Speech Voice Source Selector */}
          <div style={{ marginBottom: '1.25rem' }}>
            <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600, display: 'block', marginBottom: '8px' }}>
              Step 1A: Select Speech Voice Source
            </label>

            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              <button
                onClick={isRecording ? stopRecording : startRecording}
                className={isRecording ? 'btn-danger recording-pulse' : `btn-secondary ${audioSourceType === 'mic' ? 'active' : ''}`}
                style={{ flex: 1, justifyContent: 'center', minWidth: '130px' }}
              >
                {isRecording ? <><MicOff size={16} /> Stop ({recordTime}s)</> : <><Mic size={16} /> {audioSourceType === 'mic' ? '🎤 Mic Recorded' : 'Record Mic Voice'}</>}
              </button>

              <label className={`btn-secondary ${audioSourceType === 'file' ? 'active' : ''}`} style={{ flex: 1, justifyContent: 'center', cursor: 'pointer', textAlign: 'center', minWidth: '130px' }}>
                <FileAudio size={16} /> {audioSourceType === 'file' ? '📁 File Loaded' : 'Upload File'}
                <input type="file" accept="audio/*" onChange={handleFileUpload} style={{ display: 'none' }} />
              </label>

              <button
                onClick={handleSwitchToSynthetic}
                className={`btn-secondary ${audioSourceType === 'preset' ? 'active' : ''}`}
                style={{ justifyContent: 'center' }}
                title="Reset to synthetic benchmark voice"
              >
                🤖 Demo Voice
              </button>
            </div>
          </div>

          {/* Section 1B: Noise Environment Profile */}
          <div>
            <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600, display: 'block', marginBottom: '8px' }}>
              Step 1B: Layer Background Noise
            </label>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
              {[
                { id: 'cafe', name: '☕ Cafe Chatter', snr: -4.2 },
                { id: 'engine', name: '🚗 Engine Drone', snr: 1.5 },
                { id: 'white', name: '📻 White Hiss', snr: -6.8 },
                { id: 'street', name: '🚦 Street Traffic', snr: 0.8 },
                { id: 'keyboard', name: '⌨️ Typing Clicks', snr: 4.5 },
                { id: 'none', name: '🚫 No Added Noise', snr: 0.0 },
              ].map((item) => (
                <button
                  key={item.id}
                  onClick={() => handleSelectNoise(item.id, item.snr)}
                  className={`glass-card-interactive ${selectedNoiseType === item.id ? 'active' : ''}`}
                  style={{ padding: '8px 10px', textAlign: 'left', fontSize: '0.82rem', fontWeight: 600 }}
                >
                  <div>{item.name}</div>
                  <div style={{ fontSize: '0.70rem', color: 'var(--text-muted)' }}>
                    {item.id === 'none' ? 'Raw Input Direct' : `SNR: ${item.snr} dB`}
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Section 1C: Raw Speech Voice Preview Player */}
          {rawVoiceBuffer && (audioSourceType === 'mic' || audioSourceType === 'file') && (
            <div style={{ background: 'rgba(52, 211, 153, 0.08)', padding: '10px 14px', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(52, 211, 153, 0.3)', marginTop: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#34d399', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  {audioSourceType === 'mic' ? <Mic size={15} /> : <FileAudio size={15} />}
                  {audioSourceType === 'mic' ? 'Raw Recorded Mic Voice' : 'Raw Uploaded Audio File'}
                </div>
                <div style={{ fontSize: '0.70rem', color: 'var(--text-muted)' }}>
                  {rawVoiceBuffer.duration.toFixed(1)}s • Pure Voice (No Synthetic Noise)
                </div>
              </div>

              <button
                onClick={togglePlayRaw}
                className="btn-secondary"
                style={{ borderColor: '#34d399', color: isPlayingRaw ? '#ef4444' : '#34d399', padding: '6px 12px', fontSize: '0.8rem' }}
              >
                {isPlayingRaw ? <><Pause size={14} /> Stop Raw</> : <><Play size={14} /> Play Raw Voice</>}
              </button>
            </div>
          )}
        </div>

        {/* Step 2: Denoising Parameters */}
        <div className="glass-panel" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '1.25rem' }}>
            <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'var(--accent-purple)', color: '#fff', fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.85rem' }}>2</div>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Neural Masking Tuning</h3>
          </div>

          {/* SNR Slider */}
          <div style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.88rem' }}>
              <span style={{ color: 'var(--text-muted)' }}>Initial Input SNR:</span>
              <span style={{ fontWeight: 700, color: 'var(--accent-amber)' }}>{targetSNR} dB</span>
            </div>
            <input
              type="range"
              min="-10"
              max="10"
              step="0.5"
              value={targetSNR}
              onChange={(e) => setTargetSNR(parseFloat(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--accent-amber)' }}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '4px' }}>
              <span>-10 dB (Heavy Noise)</span>
              <span>+10 dB (Clean Speech)</span>
            </div>
          </div>

          {/* Suppression Strength Slider */}
          <div style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.88rem' }}>
              <span style={{ color: 'var(--text-muted)' }}>Ideal Ratio Mask (IRM) Cutoff:</span>
              <span style={{ fontWeight: 700, color: 'var(--primary-cyan)' }}>{Math.round(suppressionStrength * 100)}%</span>
            </div>
            <input
              type="range"
              min="0.3"
              max="1.0"
              step="0.05"
              value={suppressionStrength}
              onChange={(e) => setSuppressionStrength(parseFloat(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--primary-cyan)' }}
            />
          </div>

          {/* Run Button */}
          <button
            onClick={runDenoisingEngine}
            disabled={isProcessing || !noisyBuffer}
            className="btn-primary"
            style={{ width: '100%', justifyContent: 'center', padding: '14px' }}
          >
            {isProcessing ? (
              <><RefreshCw size={18} className="spin" /> Processing Neural Mask...</>
            ) : (
              <><Sparkles size={18} /> ✨ Suppress Background Noise</>
            )}
          </button>
        </div>

        {/* Live Metrics Summary */}
        <div className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '1rem' }}>
            <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'var(--accent-green)', color: '#000', fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.85rem' }}>3</div>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Signal Improvement Metrics</h3>
          </div>

          {metrics ? (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ background: 'rgba(255,255,255,0.03)', padding: '12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Input SNR</div>
                <div style={{ fontSize: '1.3rem', fontWeight: 800, color: 'var(--accent-red)' }}>{metrics.inputSNR} dB</div>
              </div>
              <div style={{ background: 'rgba(0, 210, 255, 0.08)', padding: '12px', borderRadius: 'var(--radius-md)', border: '1px solid rgba(0, 210, 255, 0.3)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Denoised Output SNR</div>
                <div style={{ fontSize: '1.3rem', fontWeight: 800, color: 'var(--primary-cyan)' }}>{metrics.outputSNR} dB</div>
              </div>
              <div style={{ background: 'rgba(16, 185, 129, 0.08)', padding: '12px', borderRadius: 'var(--radius-md)', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Net SNR Gain</div>
                <div style={{ fontSize: '1.3rem', fontWeight: 800, color: '#34d399' }}>{metrics.snrImprovement} dB</div>
              </div>
              <div style={{ background: 'rgba(139, 92, 246, 0.08)', padding: '12px', borderRadius: 'var(--radius-md)', border: '1px solid rgba(139, 92, 246, 0.3)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>STOI Intelligibility</div>
                <div style={{ fontSize: '1.3rem', fontWeight: 800, color: '#c084fc' }}>{metrics.stoiScore}</div>
              </div>
            </div>
          ) : (
            <div style={{ textAlignment: 'center', padding: '2rem 1rem', color: 'var(--text-dim)', textAlign: 'center' }}>
              <Zap size={36} color="var(--text-dim)" style={{ marginBottom: '8px' }} />
              <div>Click <strong>"Suppress Background Noise"</strong> to compute real-time SNR and STOI metrics.</div>
            </div>
          )}

          {denoisedBuffer && (
            <button
              onClick={downloadDenoisedWav}
              className="btn-secondary"
              style={{ width: '100%', justifyContent: 'center', marginTop: '1rem', borderColor: 'var(--accent-green)', color: '#34d399' }}
            >
              <Download size={16} /> Export Denoised WAV
            </button>
          )}
        </div>

      </div>

      {/* Multi-Stage Processing Indicator */}
      {isProcessing && (
        <div className="glass-panel" style={{ padding: '1.5rem', marginBottom: '2rem', border: '1px solid var(--primary-cyan)' }}>
          <div style={{ fontSize: '0.9rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--primary-cyan)', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Activity className="spin" size={18} /> Neural Denoising Pipeline Executing...
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '10px' }}>
            {[
              { id: 1, name: '1. STFT Spectrogram' },
              { id: 2, name: '2. 2D CNN Features' },
              { id: 3, name: '3. LSTM Dynamics' },
              { id: 4, name: '4. Ideal Ratio Mask' }
            ].map((step) => (
              <div
                key={step.id}
                style={{
                  padding: '10px',
                  borderRadius: 'var(--radius-sm)',
                  background: currentStep >= step.id ? 'rgba(0, 210, 255, 0.15)' : 'rgba(255,255,255,0.03)',
                  border: currentStep >= step.id ? '1px solid var(--primary-cyan)' : '1px solid var(--border-color)',
                  color: currentStep >= step.id ? 'var(--primary-cyan)' : 'var(--text-dim)',
                  fontSize: '0.82rem',
                  fontWeight: 600
                }}
              >
                {step.name} {currentStep >= step.id && '✓'}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Active Voice Source Status Indicator */}
      <div className="glass-panel" style={{ padding: '0.85rem 1.25rem', marginBottom: '1.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(0, 210, 255, 0.05)', borderColor: 'rgba(0, 210, 255, 0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '0.9rem', fontWeight: 600 }}>
          {audioSourceType === 'mic' && (
            <span style={{ color: '#34d399', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Mic size={18} /> <strong>Active Speech Input:</strong> Live Recorded Microphone Voice ({rawVoiceBuffer?.duration.toFixed(1)}s)
            </span>
          )}
          {audioSourceType === 'file' && (
            <span style={{ color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <FileAudio size={18} /> <strong>Active Speech Input:</strong> Uploaded Custom Audio File ({rawVoiceBuffer?.duration.toFixed(1)}s)
            </span>
          )}
          {audioSourceType === 'preset' && (
            <span style={{ color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Sparkles size={18} color="var(--primary-cyan)" /> <strong>Active Speech Input:</strong> Synthetic Speech Benchmark (3.5s)
            </span>
          )}
        </div>

        <span className="badge" style={{ background: selectedNoiseType === 'none' ? 'rgba(52, 211, 153, 0.15)' : 'rgba(239, 68, 68, 0.15)', color: selectedNoiseType === 'none' ? '#34d399' : '#f87171', border: '1px solid currentColor' }}>
          {selectedNoiseType === 'none' ? '🚫 No Added Noise' : `🔊 Layered Noise: ${selectedNoiseType.toUpperCase()} (${targetSNR} dB)`}
        </span>
      </div>

      {/* Audio Waveform & Spectrogram Comparison Panels */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
        
        {/* Noisy Input Panel */}
        <div className="glass-panel" style={{ padding: '1.5rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <div>
              <h4 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--accent-red)' }}>
                🔴 Original Input Signal
              </h4>
              <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                {audioSourceType === 'mic' ? 'Live Recorded Microphone Voice' : audioSourceType === 'file' ? 'Uploaded Custom Audio File' : `${selectedNoiseType.toUpperCase()} Synthetic Noise`}
              </span>
            </div>
            <button
              onClick={togglePlayNoisy}
              className="btn-secondary"
              disabled={!noisyBuffer}
              style={{ borderColor: 'var(--accent-red)', color: isPlayingNoisy ? '#ef4444' : '#fca5a5' }}
            >
              {isPlayingNoisy ? <><Pause size={16} /> Stop Audio</> : <><Play size={16} /> Play Noisy</>}
            </button>
          </div>

          {/* Time Domain Waveform */}
          <div style={{ marginBottom: '1rem' }}>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>Time-Domain Waveform</div>
            <canvas ref={canvasNoisyWaveRef} width={500} height={90} style={{ width: '100%', height: 90, borderRadius: 'var(--radius-sm)', background: '#0a0d14', border: '1px solid rgba(239, 68, 68, 0.2)' }} />
          </div>

          {/* Time Frequency Spectrogram */}
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>STFT Spectrogram Heatmap (0 - 8 kHz)</div>
            <canvas ref={canvasNoisySpecRef} width={500} height={120} style={{ width: '100%', height: 120, borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)' }} />
          </div>
        </div>

        {/* Clean Denoised Panel */}
        <div className="glass-panel" style={{ padding: '1.5rem', borderColor: denoisedBuffer ? 'var(--primary-cyan)' : 'var(--border-color)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <div>
              <h4 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--primary-cyan)' }}>
                ✨ Denoised Clean Signal
              </h4>
              <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                Processed via CNN-LSTM Masking
              </span>
            </div>
            <button
              onClick={togglePlayClean}
              className="btn-primary"
              disabled={!denoisedBuffer}
            >
              {isPlayingClean ? <><Pause size={16} /> Stop Audio</> : <><Play size={16} /> Play Denoised</>}
            </button>
          </div>

          {/* Time Domain Waveform */}
          <div style={{ marginBottom: '1rem' }}>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>Time-Domain Waveform</div>
            <canvas ref={canvasCleanWaveRef} width={500} height={90} style={{ width: '100%', height: 90, borderRadius: 'var(--radius-sm)', background: '#0a0d14', border: '1px solid rgba(0, 210, 255, 0.2)' }} />
          </div>

          {/* Time Frequency Spectrogram */}
          <div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '4px' }}>STFT Spectrogram Heatmap (Noise Suppressed)</div>
            <canvas ref={canvasCleanSpecRef} width={500} height={120} style={{ width: '100%', height: 120, borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)' }} />
          </div>
        </div>

      </div>

    </div>
  );
}
