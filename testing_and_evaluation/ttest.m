function [h, p, ci, stats] = ttest(x, y, alpha)
% TTEST Paired t-test fallback for machines without the Statistics Toolbox.
% Computes paired t-test of x and y using MATLAB's built-in betainc.

if nargin < 3
    alpha = 0.05;
end

% Ensure columns
x = x(:);
y = y(:);

% Paired t-test is a one-sample t-test on the differences
d = x - y;
n = length(d);

if n < 2
    h = 0; p = NaN; ci = [NaN; NaN];
    stats = struct('tstat', NaN, 'df', 0, 'sd', 0);
    return;
end

m = mean(d);
s = std(d);
df = n - 1;

tstat = m / (s / sqrt(n) + eps);

% Two-tailed p-value using the incomplete beta function (betainc)
% Relationship between t-distribution CDF and incomplete beta function:
% P(T <= t) = 1 - 0.5 * betainc(df / (df + t^2), df/2, 0.5)
x_beta = df / (df + tstat^2 + eps);
p = betainc(x_beta, df/2, 0.5);

% Reject null hypothesis if p-value is less than significance level
h = double(p < alpha);

% Critical t-value approximation for two-tailed 95% confidence interval
% (Uses normal approximation 1.96 adjusted for small degrees of freedom)
t_crit = 1.96 + 2.4/df;
ci = [m - t_crit * s / sqrt(n); m + t_crit * s / sqrt(n)];

stats = struct('tstat', tstat, 'df', df, 'sd', s);

end
