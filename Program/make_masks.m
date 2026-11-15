function [noiseroi, ro_noiseroi, pe_noiseroi] = make_masks(bwidth, nx, ny)
% MAKE_MASKS - 4 corner noise, readout noise (left/right), and pe_noise (top/bottom)
%  bwidth - border width. optionally 2 values ro_width, pe_height
% bwidth=12; nx=94;ny=94; % prisma phantom
% bwidth=[8 12]; nx=128,ny=128 % terrax phantom
%
%hzrng = [13 81]; % Horizontal range of phantom width (prisma QC phantom)
%  |no pe pe pe no|
%  |ro----------ro|
%  |ro----------ro|
%  |ro----------ro|
%  |no pe pe pe ro|

% if input is single number, x and y and max will all be the same
bwidth_y=bwidth(1);
bwidth_x=bwidth(end);
bwidth_m=max(bwidth);

% 4 corner noise ROI  (cyan in Fig. 2D)
noiseroi1 = [2 bwidth_m;
             2 bwidth_m];
noiseroi2 = [2 bwidth_m;
             ny-bwidth_m+1 ny-1];
noiseroi3 = [nx-bwidth_m+1 nx-1;
             2 bwidth_m];
noiseroi4 = [nx-bwidth_m+1 nx-1;
             ny-bwidth_m+1 ny-1];
noiseroi = fill_rect(zeros(nx,ny),1, ...
                     {noiseroi1; noiseroi2
                      noiseroi3; noiseroi4});

% Read Out issues will appear as ghosting on the left or right of the image
% RO noise ROI <- central range in PE direction (green in Fig. 2D)
% 20250312 - shift by a pixel
%from: ro_noiseroi1 = [13 82; 2 12]; ro_noiseroi2 = [13 82; 83 93];
%to:   ro_noiseroi1 = [13 82; 1 12]; ro_noiseroi2 = [13 82; 83 94];
% 20261114 - no bottom overlap 
ro_noiseroi = fill_rect(zeros(nx,ny),1, ...
                        {[bwidth_x+1 nx-bwidth_x;
                          1        bwidth_y]
                         [bwidth_x+1  nx-bwidth_x;
                          ny-bwidth_y+1 ny]});

% Phase Encoding issues will appear as aliasing in the top or bottom of the image
% PE noise ROI <- brown area in Fig. 2D
%pe_noiseroi1 = [2 12; 13 82];
%pe_noiseroi2 = [83 93; 13 82];
% 20261114 - made asym with bwidth_{x,y}
% TODO: consider useing bwidth_m to avoid shairng readout block
pe_noiseroi = fill_rect(zeros(nx,ny), 1,...
                        {[2           bwidth_x
                          bwidth_y+1    ny-bwidth_y],...
                         [nx-bwidth_x+1 nx-1
                          bwidth_y+1    ny-bwidth_y]});
end
