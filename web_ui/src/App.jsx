import React, { useState } from 'react';
import Header from './components/Header';
import InteractiveStudio from './components/InteractiveStudio';
import EvaluationAnalytics from './components/EvaluationAnalytics';
import ArchitectureExplorer from './components/ArchitectureExplorer';
import AudioLibrary from './components/AudioLibrary';

export default function App() {
  const [activeTab, setActiveTab] = useState('studio');

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Header activeTab={activeTab} setActiveTab={setActiveTab} />
      
      <main style={{ flex: 1 }}>
        {activeTab === 'studio' && <InteractiveStudio />}
        {activeTab === 'evaluation' && <EvaluationAnalytics />}
        {activeTab === 'architecture' && <ArchitectureExplorer />}
        {activeTab === 'library' && <AudioLibrary />}
      </main>

      <footer style={{ borderTop: '1px solid var(--border-color)', padding: '1.5rem 0', background: 'rgba(0,0,0,0.4)', marginTop: 'auto' }}>
        <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
          <div>
            © {new Date().getFullYear()} MathWorks AI Studio & Breakthrough Tech AI • Team 9
          </div>
          <div style={{ display: 'flex', gap: '1.5rem' }}>
            <span>CNN-LSTM Model</span>
            <span>STFT Ideal Ratio Masking</span>
            <span>Microsoft DNS Dataset</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
