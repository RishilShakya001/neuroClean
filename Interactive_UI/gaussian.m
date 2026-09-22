clc;
clear;
close all;

mu = 5;
variance = 4;
sigma = sqrt(variance);

N = 10000;
x = mu + sigma * randn(1, N);


histogram(x, 'Normalization', 'pdf');
hold on;


t = linspace(mu - 4*sigma, mu + 4*sigma, 1000);
pdf = (1/(sigma*sqrt(2*pi)))*exp(-((t-mu).^2)/(2*sigma^2));

plot(t, pdf, 'LineWidth', 2);

xlabel('x');
ylabel('Probability Density');
title('Gaussian Distribution (\mu = 5, Variance = 4)');
legend('Generated Data', 'Theoretical PDF');
grid on;