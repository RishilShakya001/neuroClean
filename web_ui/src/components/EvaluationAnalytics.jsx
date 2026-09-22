import React from 'react';
import { BarChart3, TrendingUp, ShieldCheck, Award, FileText, CheckCircle } from 'lucide-react';

export default function EvaluationAnalytics() {
  const stratifiedData = [
    { range: 'Very Low (<-5 dB)', files: 109, snrGain: 16.74, stoiGain: 0.044, color: '#ef4444' },
    { range: 'Low (-5 to 0 dB)', files: 483, snrGain: 12.85, stoiGain: 0.041, color: '#f59e0b' },
    { range: 'Medium (0 to 5 dB)', files: 282, snrGain: 8.49, stoiGain: 0.043, color: '#3b82f6' },
    { range: 'High (5 to 10 dB)', files: 98, snrGain: 3.18, stoiGain: 0.036, color: '#10b981' },
    { range: 'Very High (>10 dB)', files: 15, snrGain: -0.54, stoiGain: 0.020, color: '#8b5cf6' },
  ];

  return (
    <div className="container" style={{ paddingBottom: '4rem' }}>
      
      {/* Title */}
      <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.75rem' }}>
          Model Evaluation & <span className="gradient-text">Benchmark Results</span>
        </h2>
        <p style={{ color: 'var(--text-muted)', maxWidth: '700px', margin: '0 auto', fontSize: '1rem' }}>
          Empirical evaluation results across the Microsoft DNS Challenge test dataset evaluated using MATLAB.
        </p>
      </div>

      {/* Top Highlights Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.25rem', marginBottom: '2.5rem' }}>
        
        <div className="glass-panel" style={{ padding: '1.5rem', textAlign: 'center', borderTop: '3px solid var(--primary-cyan)' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.82rem', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>
            Average SNR Improvement
          </div>
          <div style={{ fontSize: '2.4rem', fontWeight: 800, color: 'var(--primary-cyan)' }}>
            +10.87 dB
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--accent-green)', marginTop: '4px' }}>
            ▲ 358.6% Relative SNR Gain
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.5rem', textAlign: 'center', borderTop: '3px solid var(--accent-purple)' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.82rem', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>
            Average STOI Score Gain
          </div>
          <div style={{ fontSize: '2.4rem', fontWeight: 800, color: '#c084fc' }}>
            +0.041
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px' }}>
            0.878 ➔ 0.919 Intelligibility
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.5rem', textAlign: 'center', borderTop: '3px solid var(--accent-green)' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.82rem', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>
            Success Rate (% Files Improved)
          </div>
          <div style={{ fontSize: '2.4rem', fontWeight: 800, color: '#34d399' }}>
            98.5%
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px' }}>
            90.5% STOI Improvement Rate
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '1.5rem', textAlign: 'center', borderTop: '3px solid var(--accent-amber)' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.82rem', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>
            Training Dataset Size
          </div>
          <div style={{ fontSize: '2.4rem', fontWeight: 800, color: '#fbbf24' }}>
            5,000 Files
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '4px' }}>
            Microsoft DNS VCTK Dataset
          </div>
        </div>

      </div>

      {/* Stratified Performance Section */}
      <div className="glass-panel" style={{ padding: '2rem', marginBottom: '2.5rem' }}>
        <h3 style={{ fontSize: '1.4rem', fontWeight: 700, marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <BarChart3 color="var(--primary-cyan)" /> Stratified SNR Performance Breakdown
        </h3>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
          The CNN-LSTM model delivers maximum denoising power for audio clips with heavy noise {"(<-5 dB SNR)"}, restoring clarity in severe low-SNR environments.
        </p>

        {/* Bar Visualizer */}
        <div style={{ marginBottom: '2rem' }}>
          {stratifiedData.map((item, idx) => (
            <div key={idx} style={{ marginBottom: '1.25rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.88rem' }}>
                <span style={{ fontWeight: 600 }}>{item.range} ({item.files} files)</span>
                <span style={{ fontWeight: 700, color: item.color }}>+{item.snrGain} dB SNR Gain</span>
              </div>
              <div style={{ height: 14, borderRadius: 7, background: 'rgba(255,255,255,0.05)', overflow: 'hidden', display: 'flex' }}>
                <div
                  style={{
                    width: `${Math.max(3, (item.snrGain / 18) * 100)}%`,
                    background: `linear-gradient(90deg, ${item.color} 0%, ${item.color}cc 100%)`,
                    borderRadius: 7,
                    transition: 'width 1s ease'
                  }}
                />
              </div>
            </div>
          ))}
        </div>

        {/* Data Table */}
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-color)', color: 'var(--text-muted)' }}>
                <th style={{ padding: '12px' }}>Input SNR Range</th>
                <th style={{ padding: '12px' }}>Test Sample Count</th>
                <th style={{ padding: '12px' }}>Avg SNR Gain (dB)</th>
                <th style={{ padding: '12px' }}>Avg STOI Gain</th>
                <th style={{ padding: '12px' }}>Performance Impact</th>
              </tr>
            </thead>
            <tbody>
              {stratifiedData.map((row, idx) => (
                <tr key={idx} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                  <td style={{ padding: '12px', fontWeight: 600 }}>{row.range}</td>
                  <td style={{ padding: '12px' }}>{row.files}</td>
                  <td style={{ padding: '12px', fontWeight: 700, color: row.color }}>+{row.snrGain} dB</td>
                  <td style={{ padding: '12px', fontWeight: 600, color: '#34d399' }}>+{row.stoiGain}</td>
                  <td style={{ padding: '12px' }}>
                    <span className={`badge ${row.snrGain > 10 ? 'badge-cyan' : row.snrGain > 0 ? 'badge-purple' : 'badge-green'}`}>
                      {row.snrGain > 10 ? '🔥 Exceptional Suppression' : row.snrGain > 0 ? '⚡ Strong Enhancement' : '⚖️ Preservation'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* PDF Presentation Card */}
      <div className="glass-panel" style={{ padding: '1.75rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <FileText size={36} color="var(--primary-cyan)" />
          <div>
            <h4 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0 }}>MathWorks Final Presentation Slides</h4>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: 0 }}>
              Official project presentation PDF available in the workspace root directory.
            </p>
          </div>
        </div>
        <a
          href="/Mathworks Denoising Speech Final Presentation.pdf"
          target="_blank"
          rel="noreferrer"
          className="btn-primary"
        >
          <FileText size={16} /> Open Presentation PDF
        </a>
      </div>

    </div>
  );
}
