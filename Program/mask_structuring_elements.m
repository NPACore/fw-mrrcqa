if exist('OCTAVE_VERSION', 'builtin') ~= 0; error('USE MATLAB TO BUILD mask_structuring_elements.mat'); end
% octave doesn't support strel's matlab default of n=4
se = strel('disk', 3);  % mask (values > 1.2 * mean)
sec = strel('disk', 7); % centering mask
save('mask_structuring_elements.mat', 'se','sec')
