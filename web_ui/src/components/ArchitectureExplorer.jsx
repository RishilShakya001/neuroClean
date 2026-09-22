import React from 'react';
import { Cpu, Layers, Activity, ArrowRight, Zap, Code, ShieldCheck } from 'lucide-react';

export default function ArchitectureExplorer() {
  return (
    <div className="container" style={{ paddingBottom: '4rem' }}>
      
      {/* Title */}
      <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.75rem' }}>
          CNN-LSTM Neural <span className="gradient-text">Architecture & Math</span>
        </h2>
        <p style={{ color: 'var(--text-muted)', maxWidth: '700px', margin: '0 auto', fontSize: '1rem' }}>
          Explore the end-to-end signal processing pipeline and deep neural network layers built in MATLAB.
        </p>
      </div>

      {/* End-to-End Pipeline Diagram */}
      <div className="glass-panel" style={{ padding: '2rem', marginBottom: '2.5rem' }}>
        <h3 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Layers color="var(--primary-cyan)" /> Signal Processing Pipeline Flow
        </h3>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem' }}>
          {[
            { step: '01', title: 'Audio Input', desc: '48 kHz ➔ 16 kHz Downsampling' },
            { step: '02', title: 'STFT Windowing', desc: '512 FFT, 128 Hop, Hann Window' },
            { step: '03', title: 'CNN Feature Extractor', desc: '2D Conv Layers + ReLU' },
            { step: '04', title: 'LSTM Context', desc: 'Sequence Temporal Modeling' },
            { step: '05', title: 'IRM Synthesis', desc: 'Ideal Ratio Mask Prediction' },
            { step: '06', title: 'iSTFT Overlap-Add', desc: 'Reconstruct Clean Waveform' },
          ].map((item, idx) => (
            <div
              key={idx}
              style={{
                background: 'rgba(255,255,255,0.03)',
                padding: '1.25rem',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--border-color)',
                textAlign: 'center',
                position: 'relative'
              }}
            >
              <div style={{ fontSize: '0.75rem', fontWeight: 800, color: 'var(--primary-cyan)', marginBottom: '4px' }}>
                STEP {item.step}
              </div>
              <div style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: '4px', color: '#fff' }}>
                {item.title}
              </div>
              <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                {item.desc}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Deep Learning Architecture Details */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '2.5rem' }}>
        
        {/* CNN Component */}
        <div className="glass-panel" style={{ padding: '1.75rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '1rem' }}>
            <Cpu color="var(--primary-cyan)" size={24} />
            <h4 style={{ fontSize: '1.2rem', fontWeight: 700 }}>1. Convolutional Neural Network (CNN)</h4>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.6, marginBottom: '1rem' }}>
            The 2D CNN layers scan the Short-Time Fourier Transform (STFT) magnitude spectrogram across frequency bins. 
            CNN filters extract localized spectral patterns, such as speech formants, pitch harmonics, and noise stationary footprints.
          </p>
          <ul style={{ color: 'var(--text-muted)', fontSize: '0.85rem', paddingLeft: '1.2rem', display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <li>Input dimension: 257 frequency bins × T time frames</li>
            <li>2D Convolution kernel size: 3×3 with batch normalization</li>
            <li>ReLU activation function to capture non-linear spectral bounds</li>
          </ul>
        </div>

        {/* LSTM Component */}
        <div className="glass-panel" style={{ padding: '1.75rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '1rem' }}>
            <Activity color="#c084fc" size={24} />
            <h4 style={{ fontSize: '1.2rem', fontWeight: 700 }}>2. Long Short-Term Memory (LSTM)</h4>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.6, marginBottom: '1rem' }}>
            The recurrent LSTM layers capture long-term sequence dynamics across continuous speech frames. Speech contains phonetic context 
            where preceding and succeeding phonemes inform mask continuity, preventing audio clipping.
          </p>
          <ul style={{ color: 'var(--text-muted)', fontSize: '0.85rem', paddingLeft: '1.2rem', display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <li>2-Layer Sequence LSTM network in MATLAB Deep Learning Toolbox</li>
            <li>Sequence regression output layer for continuous frame prediction</li>
            <li>Adam Optimizer with Mean Squared Error (MSE) loss</li>
          </ul>
        </div>

      </div>

      {/* Mathematical Formulations Card */}
      <div className="glass-panel" style={{ padding: '2rem' }}>
        <h3 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1.25rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Code color="#34d399" /> Mathematical Foundations & Ideal Ratio Masking
        </h3>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
          
          <div style={{ background: 'rgba(0, 210, 255, 0.05)', padding: '1.25rem', borderRadius: 'var(--radius-md)', border: '1px solid rgba(0, 210, 255, 0.2)' }}>
            <h5 style={{ color: 'var(--primary-cyan)', fontSize: '1rem', fontWeight: 700, marginBottom: '8px' }}>
              Ideal Ratio Mask (IRM) Target
            </h5>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: '0.9rem', color: '#fff', background: '#0a0d14', padding: '10px', borderRadius: 'var(--radius-sm)', marginBottom: '8px' }}>
              IRM(f, t) = √ [ |S(f, t)|² / ( |S(f, t)|² + |N(f, t)|² ) ]
            </div>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: 0 }}>
              Where S(f,t) is clean speech power and N(f,t) is noise power at frequency bin f and frame t.
            </p>
          </div>

          <div style={{ background: 'rgba(139, 92, 246, 0.05)', padding: '1.25rem', borderRadius: 'var(--radius-md)', border: '1px solid rgba(139, 92, 246, 0.2)' }}>
            <h5 style={{ color: '#c084fc', fontSize: '1rem', fontWeight: 700, marginBottom: '8px' }}>
              Short-Time Fourier Transform (STFT)
            </h5>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: '0.9rem', color: '#fff', background: '#0a0d14', padding: '10px', borderRadius: 'var(--radius-sm)', marginBottom: '8px' }}>
              X(k, m) = Σ x[n] · w[n - mH] · e^(-j 2π k n / N)
            </div>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: 0 }}>
              window w[n] = Hann window, H = hop size (128 samples), N = FFT size (512 points).
            </p>
          </div>

        </div>
      </div>

    </div>
  );
}
