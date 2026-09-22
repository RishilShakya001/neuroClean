clc; clear; close all;

%% Step I: Input sequence
x = [1 2 3 4];
N = length(x);

%% Step II: Manual DFT
XM = zeros(1,N);

for k = 0:N-1
    for n = 0:N-1
        XM(k+1) = XM(k+1) + x(n+1)*exp(-1j*2*pi*k*n/N);
    end
end

%% Step III: Manual IDFT
XMI = zeros(1,N);

for n = 0:N-1
    for k = 0:N-1
        XMI(n+1) = XMI(n+1) + XM(k+1)*exp(1j*2*pi*k*n/N);
    end
end

XMI = XMI/N;

%% Step IV: Inbuilt DFT and IDFT
X_fft = fft(x);
x_ifft = ifft(X_fft);

%% Step V: Plot 5 graphs
n = 0:N-1;

figure('Name','DFT and IDFT','NumberTitle','off');

subplot(5,1,1);
stem(n,x,'filled');
title('1. Original Sequence x(n)');
xlabel('n');
ylabel('Amplitude');
grid on;

subplot(5,1,2);
stem(n,abs(XM),'filled');
title('2. Manual DFT |X(k)|');
xlabel('k');
ylabel('Magnitude');
grid on;

subplot(5,1,3);
stem(n,abs(X_fft),'filled');
title('3. Inbuilt DFT |X(k)|');
xlabel('k');
ylabel('Magnitude');
grid on;

subplot(5,1,4);
stem(n,real(XMI),'filled');
title('4. Manual IDFT x(n)');
xlabel('n');
ylabel('Amplitude');
grid on;

subplot(5,1,5);
stem(n,real(x_ifft),'filled');
title('5. Inbuilt IDFT x(n)');
xlabel('n');
ylabel('Amplitude');
grid on;

%% Display results
disp('Manual DFT:');
disp(XM);

disp('Inbuilt DFT:');
disp(X_fft);

disp('Manual IDFT:');
disp(real(XMI));

disp('Inbuilt IDFT:');
disp(real(x_ifft));