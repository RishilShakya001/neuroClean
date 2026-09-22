import React, { useState, useEffect } from 'react';
import { Music, Play, Pause, Sparkles, CheckCircle, Volume2, ShieldCheck } from 'lucide-react';
import { generateVoiceBuffer, generateNoiseBuffer, mixAudioBuffers, denoiseAudioBuffer } from '../utils/audioProcessor';

export default function AudioLibrary() {
  const [audioCtx, setAudioCtx] = useState(null);
  const [activeSampleId, setActiveSampleId] = useState(null);
  const [processedSamples, setProcessedSamples] = useState({});
  const [playingId, setPlayingId] = useState(null);

  useEffect(() => {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    setAudioCtx(ctx);
    return () => ctx.close();
  }, []);

  const libraryItems = [
    { id: 1, title: 'VCTK Speaker 250 + Cafe Background Chatter', noise: 'cafe', snr: -4.2, strat: 'Very Low SNR (<-5dB)', color: '#ef4444' },
    { id: 2, title: 'VCTK Speaker 255 + Low Frequency Engine Hum', noise: 'engine', snr: 1.5, strat: 'Low SNR (-5 to 0dB)', color: '#f59e0b' },
    { id: 3, title: 'VCTK Speaker 414 + Gaussian White Noise Hiss', noise: 'white', snr: -6.8, strat: 'Very Low SNR (<-5dB)', color: '#ef4444' },
    { id: 4, title: 'Female Speaker + Street Traffic & Horns', noise: 'street', snr: 0.8, strat: 'Medium SNR (0 to 5dB)', color: '#3b82f6' },
    { id: 5, title: 'Male Speaker + Keyboard Burst Clicks', noise: 'keyboard', snr: 4.5, strat: 'High SNR (5 to 10dB)', color: '#10b981' },
  ];

  const processSample = (item) => {
    if (!audioCtx) return;
    setActiveSampleId(item.id);

    const voiceBuf = generateVoiceBuffer(audioCtx, 3.0);
    const noiseBuf = generateNoiseBuffer(audioCtx, item.noise, 3.0);
    const { mixedBuffer } = mixAudioBuffers(audioCtx, voiceBuf, noiseBuf, item.snr);
    const { denoisedBuffer, metrics } = denoiseAudioBuffer(audioCtx, mixedBuffer, 0.88);

    setProcessedSamples((prev) => ({
      ...prev,
      [item.id]: { mixedBuffer, denoisedBuffer, metrics }
    }));
    setActiveSampleId(null);
  };

  const playAudio = async (buffer, idTag) => {
    if (!audioCtx || !buffer) return;
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }
    const source = audioCtx.createBufferSource();
    source.buffer = buffer;
    source.connect(audioCtx.destination);
    source.onended = () => setPlayingId(null);
    source.start(0);
    setPlayingId(idTag);
  };

  return (
    <div className="container" style={{ paddingBottom: '4rem' }}>
      
      {/* Title */}
      <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.75rem' }}>
          Test Audio <span className="gradient-text">Sample Suite</span>
        </h2>
        <p style={{ color: 'var(--text-muted)', maxWidth: '700px', margin: '0 auto', fontSize: '1rem' }}>
          Explore representative evaluation audio files across different noise environments and SNR ranges.
        </p>
      </div>

      {/* Catalog Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '1.5rem' }}>
        {libraryItems.map((item) => {
          const res = processedSamples[item.id];
          const isProcessing = activeSampleId === item.id;

          return (
            <div key={item.id} className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                  <span className="badge" style={{ background: `${item.color}15`, color: item.color, border: `1px solid ${item.color}40` }}>
                    {item.strat}
                  </span>
                  <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                    Target SNR: {item.snr} dB
                  </span>
                </div>

                <h4 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem', color: '#fff' }}>
                  {item.title}
                </h4>
              </div>

              <div>
                {!res ? (
                  <button
                    onClick={() => processSample(item)}
                    disabled={isProcessing}
                    className="btn-primary"
                    style={{ width: '100%', justifyContent: 'center' }}
                  >
                    {isProcessing ? 'Denoising Signal...' : <><Sparkles size={16} /> Run Denoise Benchmark</>}
                  </button>
                ) : (
                  <div>
                    {/* Metrics Badge */}
                    <div style={{ background: 'rgba(0, 210, 255, 0.08)', padding: '10px 12px', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(0, 210, 255, 0.3)', marginBottom: '1rem', display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                      <span>Net Gain: <strong style={{ color: '#34d399' }}>{res.metrics.snrImprovement} dB</strong></span>
                      <span>STOI: <strong style={{ color: '#c084fc' }}>{res.metrics.stoiScore}</strong></span>
                    </div>

                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => playAudio(res.mixedBuffer, `noisy-${item.id}`)}
                        className="btn-secondary"
                        style={{ flex: 1, justifyContent: 'center', fontSize: '0.8rem', padding: '8px' }}
                      >
                        {playingId === `noisy-${item.id}` ? 'Playing Noisy...' : <><Play size={14} /> Noisy Audio</>}
                      </button>

                      <button
                        onClick={() => playAudio(res.denoisedBuffer, `clean-${item.id}`)}
                        className="btn-primary"
                        style={{ flex: 1, justifyContent: 'center', fontSize: '0.8rem', padding: '8px' }}
                      >
                        {playingId === `clean-${item.id}` ? 'Playing Clean...' : <><Play size={14} /> Clean Speech</>}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

    </div>
  );
}
