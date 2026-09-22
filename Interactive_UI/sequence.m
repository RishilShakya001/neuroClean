clc;
clear;
close all;


x = [1 2 3 4 5 6];
h = [1 2 1];


x1 = [1 2 3];
x2 = [4 5 6];


y1 = conv(x1,h);
y2 = conv(x2,h);


y = zeros(1, length(x) + length(h) - 1);

y(1:length(y1)) = y1;
y(length(x1)+1:length(x1)+length(y2)) = ...
    y(length(x1)+1:length(x1)+length(y2)) + y2;

disp('y1 = ');
disp(y1);

disp('y2 = ');
disp(y2);

disp('Linear convolution using Overlap and Add = ');
disp(y);


stem(0:length(y)-1,y,'filled');
xlabel('n');
ylabel('y(n)');
title('Linear Convolution using Overlap and Add Method');
grid on;