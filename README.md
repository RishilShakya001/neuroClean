# 🎙️ AI-Based Speech Denoising System

The project aims to develop an AI-based system for reducing unwanted noise from speech signals using Digital Signal Processing (DSP) techniques and a Convolutional Neural Network (CNN). The system produces cleaner and more intelligible speech.

---

## 🔬 **Proposed Methodology**

1. **Collect Clean Speech Samples**: Collect clean human speech samples from **Mozilla Common Voice** and the Microsoft DNS Challenge dataset (English VCTK speech subset).
2. **DSP Preprocessing**: Prepare the audio data using DSP techniques—resampling signals to 16 kHz, converting multi-channel audio to mono, and normalizing amplitude.
3. **Introduce Suitable Noise**: Mix clean speech with real-world noise environments (*Cafe Chatter, Engine Drone, White Noise, Street Traffic, Keyboard Clicks*) at controlled SNR levels (-10 dB to +10 dB) to generate noisy speech samples for training and testing.
4. **Time-Frequency Representation (STFT / Spectrogram)**: Convert audio signals into 2D time-frequency spectrogram representations using Short-Time Fourier Transform (STFT) with a 512-sample Hamming window and 75% overlap.
5. **Train CNN Model**: Build and train a **Convolutional Neural Network (CNN)** (with LSTM sequence modeling) to learn the relationship between noisy and clean speech representations by predicting an Ideal Ratio Mask (IRM).
6. **Reconstruct Enhanced Audio Signal**: Apply the trained model's predicted spectral mask to noisy speech and synthesize the enhanced time-domain audio signal using Inverse STFT (ISTFT).
7. **Evaluate Improvements**: Evaluate speech quality and signal enhancement using objective measures (**Signal-to-Noise Ratio (SNR)** and **Short-Time Objective Intelligibility (STOI)**) and subjective audio listening.

---

## 🎯 **Expected Outcome**

* The final system reduces background noise and produces cleaner, highly intelligible speech.
* Demonstrates how DSP preprocessing and deep learning can be combined effectively for practical speech enhancement in real-world applications such as hearing aids and virtual meetings.
* **Results Achieved**:
  * **Average SNR Gain**: **+10.87 dB** (358.6% relative improvement)
  * **Average STOI Improvement**: **+0.041**
  * **Noise Suppression**: Up to **96%** background noise removed

---

## 🚀 **Next Steps**

* [x] **Finalize Dataset & Preprocessing Pipeline**: Resample to 16 kHz, convert to mono, and normalize amplitude.
* [x] **Prepare Clean/Noisy Training Pairs**: Synthesize clean and noisy audio pairs across multiple SNR levels.
* [x] **Implement STFT & ISTFT Reconstruction**: Extract 257-bin magnitude spectrograms and perform windowed overlap-add signal synthesis.
* [x] **Build & Train CNN Model**: Train CNN-LSTM sequence regression model using Adam optimizer and MSE loss on 5,000 speech frames.
* [x] **Compare Noisy & Enhanced Speech**: Calculate SNR and STOI metrics and perform side-by-side audio playback.
* [x] **Optimize for Real-Time & Interactive Use**: Provide dual user interfaces via MATLAB GUI and React Web UI.

---

## 📁 **Repository Organization**

* **[`preprocessing/`](file:///e:/NeruroClean/preprocessing)**: Contains data synthesis and STFT feature extraction scripts (`combine_voice_with_noise.m`, `preprocessing_ratio_no_segments_function.m`).
* **[`train_model files/`](file:///e:/NeruroClean/train_model%20files)**: Neural network definition (`create_fixed_cnn_lstm_modelv2.m`) and model training (`main_simple.m`).
* **[`testing_and_evaluation/`](file:///e:/NeruroClean/testing_and_evaluation)**: Test audio processing (`run_test_processing.m`), SNR & STOI evaluation (`compute_evaluation_metrics.m`), and summary reports.
* **[`Interactive_UI/`](file:///e:/NeruroClean/Interactive_UI)**: MATLAB App Designer interactive GUI (`interactive_ui_denoise.m`).
* **[`web_ui/`](file:///e:/NeruroClean/web_ui)**: Standalone browser-based React application.

---

## 💻 **How to Run**

### **Option 1: Web Application (Browser-Based)**
Run the live web UI directly in your browser:
```bash
cd web_ui
npm install
npm run dev
```
Open **[http://localhost:5188/](http://localhost:5188/)** to record, upload, and test speech denoising interactively.

### **Option 2: MATLAB Interactive GUI**
Run the MATLAB figure interface inside MATLAB (R2021a or newer):
```matlab
cd('e:\NeruroClean\Interactive_UI')
interactive_ui_denoise
```
