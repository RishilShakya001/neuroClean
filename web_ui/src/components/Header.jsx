import React from 'react';
import { Activity, Cpu, Sparkles, BarChart3, Layers, Music } from 'lucide-react';

export default function Header({ activeTab, setActiveTab }) {
  return (
    <header className="glass-panel" style={{ borderRadius: 0, borderTop: 0, borderLeft: 0, borderRight: 0, marginBottom: '2rem' }}>
      <div className="container" style={{ padding: '1.25rem 1.5rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '1rem' }}>
        
        {/* Branding */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{
            width: 46,
            height: 46,
            borderRadius: 14,
            background: 'linear-gradient(135deg, #00d2ff 0%, #8b5cf6 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: 'var(--shadow-glow-cyan)'
          }}>
            <Activity size={26} color="#000" strokeWidth={2.5} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h1 style={{ fontSize: '1.4rem', fontWeight: 800, margin: 0, color: '#fff' }}>
                NeuroClean <span className="gradient-text">AI</span>
              </h1>
              <span className="badge badge-cyan">MathWorks AI Studio</span>
            </div>
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', margin: 0 }}>
              CNN-LSTM Speech Noise Suppression Engine • BTT AI Team 9
            </p>
          </div>
        </div>

        {/* Navigation Tabs */}
        <nav style={{ display: 'flex', gap: '6px', background: 'rgba(0,0,0,0.3)', padding: 4, borderRadius: 'var(--radius-md)', border: '1px solid var(--border-color)' }}>
          <button
            onClick={() => setActiveTab('studio')}
            className={`btn-secondary ${activeTab === 'studio' ? 'active' : ''}`}
            style={{
              padding: '8px 16px',
              fontSize: '0.88rem',
              borderRadius: 'var(--radius-sm)',
              border: activeTab === 'studio' ? '1px solid var(--primary-cyan)' : 'none',
              background: activeTab === 'studio' ? 'rgba(0, 210, 255, 0.15)' : 'transparent',
              color: activeTab === 'studio' ? 'var(--primary-cyan)' : 'var(--text-muted)',
            }}
          >
            <Sparkles size={16} /> Interactive Studio
          </button>
          
          <button
            onClick={() => setActiveTab('evaluation')}
            className={`btn-secondary ${activeTab === 'evaluation' ? 'active' : ''}`}
            style={{
              padding: '8px 16px',
              fontSize: '0.88rem',
              borderRadius: 'var(--radius-sm)',
              border: activeTab === 'evaluation' ? '1px solid var(--accent-purple)' : 'none',
              background: activeTab === 'evaluation' ? 'rgba(139, 92, 246, 0.15)' : 'transparent',
              color: activeTab === 'evaluation' ? '#c084fc' : 'var(--text-muted)',
            }}
          >
            <BarChart3 size={16} /> Evaluation & Metrics
          </button>

          <button
            onClick={() => setActiveTab('architecture')}
            className={`btn-secondary ${activeTab === 'architecture' ? 'active' : ''}`}
            style={{
              padding: '8px 16px',
              fontSize: '0.88rem',
              borderRadius: 'var(--radius-sm)',
              border: activeTab === 'architecture' ? '1px solid var(--accent-green)' : 'none',
              background: activeTab === 'architecture' ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
              color: activeTab === 'architecture' ? '#34d399' : 'var(--text-muted)',
            }}
          >
            <Layers size={16} /> Neural Architecture
          </button>

          <button
            onClick={() => setActiveTab('library')}
            className={`btn-secondary ${activeTab === 'library' ? 'active' : ''}`}
            style={{
              padding: '8px 16px',
              fontSize: '0.88rem',
              borderRadius: 'var(--radius-sm)',
              border: activeTab === 'library' ? '1px solid var(--accent-amber)' : 'none',
              background: activeTab === 'library' ? 'rgba(245, 158, 11, 0.15)' : 'transparent',
              color: activeTab === 'library' ? '#fbbf24' : 'var(--text-muted)',
            }}
          >
            <Music size={16} /> Test Samples
          </button>
        </nav>

        {/* Model Status Indicator */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'rgba(255,255,255,0.03)', padding: '6px 14px', borderRadius: 'var(--radius-full)', border: '1px solid var(--border-color)' }}>
          <Cpu size={18} color="var(--primary-cyan)" />
          <div>
            <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-main)' }}>
              CNN-LSTM (5,000 files)
            </div>
            <div style={{ fontSize: '0.7rem', color: 'var(--accent-green)' }}>
              ● Model Loaded (+10.87 dB SNR)
            </div>
          </div>
        </div>

      </div>
    </header>
  );
}
