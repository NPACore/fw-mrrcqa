function [stat, varargout] = dostat_xa60(pfolder,bfig, outdir)

if nargin == 0
   disp('USAGE: dostats /path/to/dicomdir 0 /path/to/savedir')
   disp('  "0" can be "1" to save a figure and mask information')
   disp('  also see run.py (/flywheel/v0/run.py in container)')
   disp('  env: MRRCQA_VERSION, QA_SAVE_IMAGES, SLICE_VERBOSE, MAXTIMEPOINTS')
   error('bad arguments')
end

calc_start_time = tic;
% load depends if running octave
% see 'pkg install dicom -forge' or e.g. 'yay -S octave-dicom' (needs GDCM lib)
if exist('OCTAVE_VERSION', 'builtin') ~= 0; pkg load dicom image; end

% print stats on every slice?
slice_verbose = ~isempty(getenv('SLICE_VERBOSE'));

% structuring element for erosion
try
  se = strel('disk', 3);  % mask (values > 1.2 * mean)
  sec = strel('disk', 7); % centering mask
catch
  % NB. octave does not support MATLABs default n=4 (line structuring elements)
  % see mask_structuring_elements.m
  cached_se = fullfile(fileparts(mfilename),'mask_structuring_elements.mat');
  if ~ exist(cached_se, 'file'), error(cached_se, ' doesnt exist!?'); end
  load(cached_se, 'sec','se');
  warning(['using cached se and sec from ', cached_se])
end

stat = [];


%{  
%% Data folder
%
%@P1
%@P1; P1 coil and P1 phantom
pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma1/QA_PRISMA1QA_20240809_173010_559000/EP2D_BOLD_P2_S2_5MIN_0003';
tlabel = 'C1P1@P1';

%@P2
%@P2; P1 coil and phantom
%pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma2/QA_PRISMA2QA_20240809_174910_732000/EP2D_BOLD_P2_S2_5MIN_0003';
%tlabel = 'C1P1@P2';
%@P2; P2 coil and P2 phantom
pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma2/QA_PRISMA2QA_20240809_180905_626000/EP2D_BOLD_P2_S2_5MIN_0003';
tlabel = 'C2P2@P2';

%@P3; P1 coil and phantom
%pfolder ='/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma3/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003';
%tlabel = 'C1P1@P3';
%@P3; P3 coil and P3 phantom
pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma3/QA_PRISMA3QA_20240809_182158_666000/EP2D_BOLD_P2_S2_5MIN_0003';
tlabel = 'C3P3@P3';
%}

[~,hostname] = system('hostname'); hostname=strtrim(hostname);
fprintf('# running as %s@%s\n', getenv('USER'), hostname)
%% Loading image data
fprintf('# [%s] searching %s\n', datestr(now), pfolder)
% look for IMA, dcm, or MR* files
D = find_all_dicoms(pfolder);
fprintf('# [%s] found %d dicoms\n', datestr(now), length(D))

% dicom information
name = D(1,1).name;
folder = D(1,1).folder;
P = [folder '/' name];
% P='/raidmeduser/OngoingResearch/7TDATA/TerraX/20260908TerraXQC_PinkLabelPhant/DICOM/ep2d_bold_p2_s2_5min_8_MR/1.dcm'
%info = dicominfo(P);
% fprintf('# reading %s\n', P);
[info, err] = dicm_hdr(P); %extended dicom info

% B0 shim value - read once (20261114), should be same for all in series
[shimvalues, shimmode, strbuff, GradSensitivity] = readshimvalues(P);
b1vals = readB1values(strbuff);

isTerraX = 0; % what kind of phantom do we have? default to prisma

afactor = 1.2; %  dicom >= mean + afactor ==> phantom data

% what kind of dicom?
% AcquisitionMatrix only in VE and earlier.
% enhanced dicom (XA) has data in 3d matrix already.
if isfield(info,'AcquisitionMatrix')
    nx = double(info.AcquisitionMatrix(1));
    ny = double(info.AcquisitionMatrix(end));
    %nz = info.Private_0019_100a;
    nz = double(info.LocationsInAcquisition);
    % mx and my only used for read_mosaic. 
    % TODO: used for roi_area and mask_thres (erronously?)
    mx = info.Columns/nx;
    my = info.Rows/ny;
    
    TR = info.RepetitionTime; %msec
    %%
    % *b*
else
    % will read first dicom twice :(
    data = squeeze(dicomread(info)); % size(data) == [658 658] % prisma
    [nx,ny,nz] = size(data); % 128,128,92 NB!! might not be x,y,z?!
    mx = nx; my=ny; % TODO: shouldn't need these
    % TR could be used for plotting. But currently isn't
    % kept here for reference
    TR = info.SharedFunctionalGroupsSequence.Item_1.MRTimingAndRelatedParametersSequence.Item_1.RepetitionTime;
end

% ep2d mosaic example dims
% 7x7 grid, each with 94x94
% [nx, ny, nz]               ==  94   94  46
% [info.Columns, info.Rows]  == 658  658
% [mx, my]                   ==   7    7
%
% TerraX(enhanced dicom):   128 x 128 x 92 

%% Pre-set index 
% see: imagesc(sum(data,3))

% PE shift <- phantom positioned high due to Siemens pad
ishift = [12 0];  % used for initial volume

bwidth = 12; % border width for
             % noise (4 corner boxes), read out (left/right rectangles), and phase encode (top/bottom rects)

% 20261114 - prisma QC acq is 94x94. TerraX QC acq is currently 128x128
%            cannot test on enhanced dicom b/c Prisma will eventually also update to XA
if nx > 96, isTerraX = 1; end
         
% TerraX "Pink" phantom sits in center of bore. no need to shift
% phantom is also bigger. readout noise box will be thinner
if isTerraX
    ishift = [0 0];
    bwidth = [8 10]; % ro width, pe height
    % intensities are very near center. when low int meants edge, get bad mask
    afactor = 1;
end

[noiseroi, ro_noiseroi, pe_noiseroi] = make_masks(bwidth, nx, ny);
% masks = noiseroi + 2^2*ro_noiseroi+2^3*pe_noiseroi; masks(masks==0)=NaN;

% 20250409 - BUG! had hardcoded nfile to 4 -- much noisier measures (but ran a lot faster)
%nfile= 4;
nfile = length(D);
% 20261114 - debugging overwrite with environment variable
if ~isempty(getenv('MAXTIMEPOINTS'))
    nfile=min(nfile,str2num(getenv('MAXTIMEPOINTS'))),
end    

% Measurement memory
phansignal = zeros(2, nz,nfile); % 1 - mean; 2 - std
totnoisesignal = zeros(2, nz,nfile);
noisesignal = zeros(2, nz,nfile);
ro_noisesignal = zeros(2, nz,nfile);
pe_noisesignal = zeros(2, nz,nfile);
aliasnoisesignal = zeros(2, nz,nfile);
mask_size = zeros(1,nz*nfile);

% Indexing
idx.phan_erode = 1;
idx.bg = 2;
idx.noise = 3;
idx.readout = 4;
idx.phaseenc = 5;
idx.alias = 6;
ALL_MASK = zeros(nx,ny,nz, 6);

% Memory
DATA = zeros(nx,ny,nz,nfile);
MASK = zeros(nx,ny,nz);

%% Looping files
%
vol_cnt = 1;   % increase with each new dicom
slice_cnt = 0; % increases with each slice (does not reset at new dicom)
               % used to index DX and DY but only when vol_cnt==1
t = [];
DX = [];
DY = [];

nmasks = 5; % mask, bg, noise, ro, pe
roi_area = zeros(mx, my, nfile, nmasks);
mask_thresh = zeros(mx, my, nfile); % collecting mnval

% make a move if we're plotting each frame
if bfig
    vidwrite = VideoWriter([outdir '/slices.avi']); % 'MPEG-4' only for win/macos :(
    vidwrite.FrameRate = 5;  % frames per second
    open(vidwrite);
end

% for each time point. first used as reference already
for i=1:nfile
    % dicom  file
    name = D(i,1).name;
    folder = D(i,1).folder;
    P = [folder '/' name]; 
    % read DICOM header including CSA information
    info = dicominfo(P);
    [s, err] = dicm_hdr(P);
    if bfig==1, disp([name ' - acq# ' num2str(s.AcquisitionNumber) ' inst#' num2str(s.InstanceNumber) ' / nfile ' num2str(nfile) ]); end
    %disp([num2str(s.InstanceNumber) ': ' num2str(shimvalues)]);
    % image
    data = squeeze(dicomread(info)); % size(data) == [658 658] % prisma
    %figure(1); imagesc(data); axis image; colormap(gray); drawnow;
    
    % enhanced dicom or mosaic dicom?
    if size(size(data),2) == 2 % Prisma/VE (v. Terra @ XA60 )
        % image size and mosaic size
        DATA(:,:,:,i) = read_mosaic(data,nx,mx,ny,my,nz);
    else
        DATA(:,:,:,i) = data;
    end

    % z-axis slice-by-slice
    for ll=1:nz
        % data in 4D
        % setup pre-shift
        DATA(:,:,ll,i) = circshift(DATA(:,:,ll,i),ishift);
        DATA(:,1,ll,i) = DATA(:,2,ll,i);
        if ll > 1
            DATA(:,:,ll,i) = circshift(DATA(:,:,ll,i),[DX(slice_cnt) DY(slice_cnt)]);
        end
        % dataslice post shift
        dataslice = DATA(:,:,ll,i);
        
        % mask per slice. per-slice centers DX,DY only calculated on first timepoint
        if vol_cnt==1
            tmp = DATA(:,:,ll,i);
            mnval = mean(mean(tmp,1),2);
            % this was min value per voxel?
            %mask_thresh(ii,jj,i) = mnval;
            
            sdval = std(std(tmp,[],1),[],2); % sd of sd
            sdval_full = std(tmp(:));
            mask = zeros(nx,ny);
            
            I = find(tmp > afactor*mnval);

            if slice_verbose
                fprintf('# t %d slice %d: sd/mn=%.2f (%.2f/%.2f) v. factor %.2f; nvox mask=%d\n',...
                  i, ll, mnval./sdval_full, mnval,sdval_full, afactor, length(I));
            end
            
            
            mask(I) = 1;
            mask=imfill(mask, 'holes');
            maskalias = circshift(mask, [nx/2 0]);
            maskalias = maskalias - and(maskalias, mask);
            
            %centering
            cemask = imerode(mask, sec);
            [I,J] = find(cemask >= 1);
            
            mask_nvox = sum(mask,'all');
            mask_size((i-1)*nz + ll) = mask_nvox;
             % empty mask -- no data.
            if isempty(I)
                fprintf('WARNING @i=%03d, slice=%03d: no values gt 1.2*mean (m=%.2f)\n',...
                    i, ll, mnval);
                continue
            end

            % find center
            I0 = ceil(mean(I));
            J0 = ceil(mean(J));
            dx = nx/2+1 - I0;
            dy = ny/2+1 - J0;
            DX = [DX dx];
            DY = [DY dy];
            
            emask = imerode(mask, se);
            emaskalias = imerode(maskalias, se);
            
            if 1
                mask = emask;
                maskalias = emaskalias;
                
                % centering
                DATA(:,:,ll,i) = circshift(DATA(:,:,ll,i),[dx dy]);
                mask = circshift(mask,[dx dy]);
                maskalias = circshift(maskalias,[dx dy]);
            end
            
            if bfig==1
                %stitle=['t = ' num2str(i) ' slice = ' num2str(ll) '/' num2str(nz)]
                stitle=sprintf('t=%03d slice %02d/%d',i, ll, nz);
                vidfig=figure(2);
                suptitle(stitle)
                subplot(2,2,1); imagesc(log(DATA(:,:,ll,i)),[0 10]); axis image; colormap(jet);
                  title(sprintf('mean=%04.2f sd=%04.2f', mnval, sdval_full));
                figure(2); subplot(2,2,2); imagesc(mask); axis image; colormap(jet);
                  title(sprintf('mask nvox=%05d', mask_nvox));
                figure(2); subplot(2,2,3); imagesc(maskalias); axis image; colormap(jet);
                  title('alias mask');
                figure(2); subplot(2,2,4); imagesc(noiseroi+2*ro_noiseroi+4*pe_noiseroi); axis image; colormap(jet);
                  title('noise masks');
                
                % will fail if -nodisplay (or DISPLAY empty b/c ssh w/o -X or -Y)
                try
                    if slice_cnt==1, set(vidfig, 'Windowstyle', 'docked'); saveas(gcf,fullfile(outdir,'mask_rois.png'),'png'); end
                end
                % 20261114 - recordvideo
                drawnow;
                writeVideo(vidwrite, getframe(vidfig));
            end
        end
        
        % mask pixel per slice
        dataslice1 = dataslice;
        maskphan1 = mask(:); Iphan1 = find(maskphan1==1);
        maskbg1 = 1-mask(:); Ibg1 = find(maskbg1==1);
        maskali1 = maskalias(:); Iali1 = find(maskali1==1);
        noiseroi1 = noiseroi(:); Inoise1 = find(noiseroi1==1);
        ro_noiseroi1 = ro_noiseroi(:); Iro_noise1 = find(ro_noiseroi1==1);
        pe_noiseroi1 = pe_noiseroi(:); Ipe_noise1 = find(pe_noiseroi1==1);
        
        % measure the signals per slice
        phansignal(1,ll,i) = mean(dataslice1(Iphan1)); phansignal(2,ll,i) = std(dataslice1(Iphan1));
        totnoisesignal(1,ll,i) = mean(dataslice1(Ibg1)); totnoisesignal(2,ll,i) = std(dataslice1(Ibg1));
        aliasnoisesignal(1,ll,i) = mean(dataslice1(Iali1)); aliasnoisesignal(2,ll,i) = std(dataslice1(Iali1));
        noisesignal(1,ll,i) = mean(dataslice1(Inoise1)); noisesignal(2,ll,i) = std(dataslice1(Inoise1));
        ro_noisesignal(1,ll,i) = mean(dataslice1(Iro_noise1)); ro_noisesignal(2,ll,i) = std(dataslice1(Iro_noise1));
        pe_noisesignal(1,ll,i) = mean(dataslice1(Ipe_noise1)); pe_noisesignal(2,ll,i) = std(dataslice1(Ipe_noise1));
        
        % phantom mask in 3D
        MASK(:,:,ll) = reshape(mask,nx,ny);
        
        % yet another mask. not touching first to ensure no change in output.
        % MASK is anywhere phantom is. at ALL_MASK(:,:,:,1) is eroded
        if ~isempty(getenv('QA_SAVE_IMAGES')) || nargout > 1
            ALL_MASK(:,:,ll, idx.phan_erode) = reshape(maskphan1, nx,ny);
            ALL_MASK(:,:,ll, idx.bg)         = reshape(maskbg1,nx,ny);
            ALL_MASK(:,:,ll, idx.alias)      = reshape(maskali1,nx,ny);
            ALL_MASK(:,:,ll, idx.noise)      = reshape(noiseroi1,nx,ny);
            ALL_MASK(:,:,ll, idx.readout)    = reshape(ro_noiseroi1,nx,ny);
            ALL_MASK(:,:,ll, idx.phaseenc)   = reshape(pe_noiseroi1,nx,ny);
        end
        
        % collect area stats
        %roi_area(ii, jj, i, :) = [sum(maskphan1), sum(maskbg1), sum(noiseroi1), sum(ro_noiseroi1), sum(pe_noiseroi1)];
        slice_cnt = slice_cnt+1; % NOTE: this increases across volumes too!
    end

    % Plot dynamic signals
    if bfig==1
    %{
    figure(3); subplot(4,1,1); plot(phansignal(1,1:i*nz),'r','LineWidth',2); axis tight; ylabel('phant');
    figure(3); subplot(4,1,2); plot(totnoisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('total noise');
    figure(3); subplot(4,1,3); plot(aliasnoisesignal(1,1:i*nz),'b','LineWidth',2); axis tight; ylabel('alias noise');
    figure(3); subplot(4,1,4); plot(noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('corner noise');
    %figure(3); subplot(6,1,5); plot(ro_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('ro noise');
    %figure(3); subplot(6,1,6); plot(pe_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('pe noise');
    %}
    figure(3); suptitle('slice@time measures');
   
    figure(3); subplot(5,1,1); plot(phansignal(1,1:i*nz)./noisesignal(2,1:i*nz),'r','LineWidth',2); axis tight; ylabel('SNR');
    figure(3); subplot(5,1,2); plot(totnoisesignal(1,1:i*nz)./noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('Bankgraound');
    figure(3); subplot(5,1,3); plot(aliasnoisesignal(1,1:i*nz)./noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('Aliasing');
    figure(3); subplot(5,1,4); plot(noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('corner noise');
    figure(3); subplot(5,1,5); plot(mask_size(1:i*nz),'b','LineWidth',2); axis tight; ylabel('mask size'); hold on;
    %yyaxis right; hold on; plot(DX(1:i*nz), 'r');plot(DY(1:i*nz), 'g'); ylabel('recenter distance')
    %figure(3); subplot(6,1,5); plot(ro_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('ro noise');
    %figure(3); subplot(6,1,6); plot(pe_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('pe noise');
    end
    
    t = [t TR*(vol_cnt-1)];
    vol_cnt = vol_cnt +1;
end

%% Statistics
%
% signal size is (2, 46, 200) - mean&sd measure per slice per timepoint
snr = phansignal(1,:)./noisesignal(2,:);
alias = aliasnoisesignal(1,:)./noisesignal(2,:);
background = totnoisesignal(1,:)./noisesignal(2,:);
noise = noisesignal(2,:);

DD = reshape(DATA,nx*ny*nz,nfile);
% 20261114 - SLOW! tsnr map. vectorize for ~4x speedup
% tsnr = zeros(1,nx*ny*nz);
%for i=1:nx*ny*nz
%    tsnr(1,i) = mean(DD(i,:))/std(DD(i,:));
%end
tsnr = (mean(DD,2) ./ std(DD')')';

I = find(MASK(:)==1);

[snrn,snrx] = hist(snr,120);
[aliasn,aliasx] = hist(alias,120);
[backgroundn,backgroundx] = hist(background,120);
[noisen,noisex] = hist(noise,120);
[tsnrn,tsnrx] = hist(tsnr(I),120);


%% Report
%
stat = struct;
[M,I] = max(snrn); stat.snrpk = snrx(I);
[M,I] = max(aliasn); stat.aliaspk = aliasx(I);
[M,I] = max(backgroundn); stat.bkoffpk = backgroundx(I);
[M,I] = max(tsnrn); stat.tsnrpk = tsnrx(I);

stat.shim = shimvalues;
stats.b1shims = b1vals;
stat.GradSensitivity = GradSensitivity;
%  uT/m values for X,Y,Z shims
stat.XYZ_uTm = calc_gradients(shimvalues, GradSensitivity);
%  X2,Y2,Z2,S2,C2 (uT/m^2)
stat.XYZ2SC_uTm2 = shimvalues(4:8);

% TODO: don't save these: 2*120 histbin value+idx that aren't that useful out of context?
stat.snr = [snrn; snrx];
stat.alias = [aliasn; aliasx];
stat.bkoff = [backgroundn; backgroundx];
stat.absnoise = [noisen; noisex];
stat.tsnr = [tsnrn; tsnrx];

% sum of first 2 dims (x-z,y-z), average of time, value per mask, bg, noise, ro, pe
% TODO: why x-z and y-z ? WF: maybe dont understand the inner most loop
% 20261112 WF commented maskVol_mbnrp -- was per voxel? (uses ii)
%stat.maskVol_mbnrp = mean(squeeze(sum(squeeze(sum(roi_area,1)),1)));
%stat.mask_thresh_mean = mean(mask_thresh(:));
%stat.mask_thresh_sd = std(mask_thresh(:));

stat.dicominfo = s;
stat.date = stat.dicominfo.StudyDate;

% 2026-03-03 - max value clipping?
stat.percent_voxels_max = 100*nnz(DATA == max(DATA(:)))/numel(DATA);
masked = DATA.*MASK;
stat.mean_mask_vol = mean(masked(masked>0));
stat.skew =skewness(masked(masked>0));

stat.calc_dur = toc(calc_start_time);

stat.version = getenv('MRRCQA_VERSION'); % exect to be stored when container is built


%% Stats plot
if bfig==1
%{
H=figure(4); p=subplot(1,4,1); p.YLabel.String='SNR'; hold on; histogram(snr,120); set(H,'Name', pfolder); hold off;
figure(4); p=subplot(1,4,2); p.YLabel.String='Aliasing'; hold on;  histogram(alias,120); hold off;
figure(4); p=subplot(1,4,3); p.YLabel.String='Background'; hold on;  histogram(background,120); hold off;
figure(4); p=subplot(1,4,4); p.YLabel.String='Noise'; hold on;  h=histogram(noise,120); hold off;
%}
H=figure(4);
suptitle('Hist 120')
p=subplot(1,5,1); ylabel(sprintf('SNR peek=%.2f',stat.snrpk)); hold on; bar(snrx,snrn,'LineWidth',2); set(H,'Name', pfolder); axis([0 500 0 400]); hold off;
  figure(4); p=subplot(1,5,2); ylabel('Aliasing'); hold on;  bar(aliasx,aliasn,'LineWidth',2); axis([0 40 0 300]);   hold off;
  figure(4); p=subplot(1,5,3); ylabel('Background Offset'); hold on;  bar(backgroundx,backgroundn,'LineWidth',2); axis([0 40 0 300]);   hold off;
  figure(4); p=subplot(1,5,4); ylabel('Absolute Noise'); hold on;  bar(noisex,noisen,'LineWidth',2); axis([0 10 0 400]);   hold off;
  figure(4); p=subplot(1,5,5); ylabel(sprintf('tSNR, peak=%.2f', stat.tsnrpk)); hold on;  bar(tsnrx,tsnrn,'LineWidth',2);  hold off;
end
%% Saving
% 20251211 - moved from QC.m to here
if nargin > 2
   fprintf('# [%s] saving to %s\n', datestr(now), outdir)
   json_outfile = fullfile(outdir, 'stats.json');
   if ~exist(outdir,'dir'), mkdir(outdir); end
   json_str = jsonencode(stat);
   fprintf('# saving %d chars of json to %s\n', length(json_str), json_outfile);
   fid = fopen(json_outfile,'w');
   fprintf(fid, '%s', json_str);
   fclose(fid);
end

% 20250821 - env variable guard;
% 20251211 - move to bottom to capture more
if ~isempty(getenv('QA_SAVE_IMAGES'))

    matfname = fullfile(outdir, 'sigstat.mat');
    maskphan = mask;
    maskbg = 1 - mask;
    mask_noiseroi = noiseroi;
    mask_ro_noiseroi = ro_noiseroi;
    mask_pe_noiseroi = pe_noiseroi;


    fprintf('# [%s] saving images to %s\n', datestr(now), matfname)
    save(matfname, 'DATA','t',...
        'maskphan','maskbg','maskalias','mask_noiseroi','mask_ro_noiseroi','mask_pe_noiseroi',...
        'phansignal','totnoisesignal','aliasnoisesignal','noisesignal','ro_noisesignal','pe_noisesignal', ...
         'roi_area', 'MASK','ALL_MASK', 'idx', ...
         'DX','DY', ... prisma: DX all 0, DY all -1
         'ishift', ... 
         'stat', ... final output
         ... signals and mean/std calcs
         'snr', 'phansignal', ...
         'tsnr', 'tsnrx','tsnrn', ...
         'alias',  'aliasnoisesignal',...
         'background','totnoisesignal', ...
         'noise', 'noisesignal' ...
        );

   % 20260602 plots. saving for hist but also getting last subplot
   saveas(gcf,fullfile(outdir,'signals.png'),'png')
   figure;
   hist(DATA(MASK==1)); title(sprintf('skew %.3f', stat.skew))
   saveas(gcf,fullfile(outdir,sprintf('mask_intensity_hist-%.2f.png',stat.skew)),'png')
else
    fprintf('# not saving mask data, set QA_SAVE_IMAGES to save\n')
end

fprintf('## Summary:\n');
fprintf('#  Phantom center shifted (DX) mean=%.1f amax=%.1f sd=%.2f; DY mean=%.1f amax=%.1f std=%.1f\n',...
        mean(DX),std(DX), max(abs(DX)), mean(DY), max(abs(DX)), std(DY));
fprintf('#  peak of 120-bin hist: snr %.2f tsnr %.2f\n',stat.snrpk,stat.tsnrpk);

%% 2026-03-03 high SNR in later slices?
%{
  zs = [12 33 46];
  for i=1:numel(zs);
    z=zs(i); subplot(1,4,i);
    m=squeeze(mean(DATA(:,:,z,:),4)); im=m.*MASK(:,:,z);
    imshow(m/max(DATA(:)));
    title(sprintf('z=%d mean=%.3f sd=%.3f', z, mean(im(im~=0)), std(im(im~=0))));
  end
  subplot(1,4,4);
  plot(squeeze(phansignal(2,1:end,:)),'b','LineWidth',2)
  % line  per time
  hold on; plot(squeeze(phansignal(2,1:end,1)),'r','LineWidth',2);
  % just second time point
  plot(snr(47:46*2),'k');
  % noise floor
  plot(noisesignal(2,1:end,1),'y');
  title('SNR by slice (46), per time (200)')
  hold off
%}
%% tsnr
%{
  [ix,iy,iz ] = ind2sub(size(MASK), find(tsnr>600));
  ux = unique(ix), uy = unique(iy), uz =unique(iz), % uz == 39:46

  td = reshape(tsnr, size(MASK));
  slice = td(:,:,44);
  rep_ex = find(slice>50 & slice < 100,1)
  too_hii = [find(td.*MASK > 300); rep_ex];

  ts=nan(numel(too_hii), size(DATA,4));
  [xx,yy,zz] = ind2sub(size(MASK), too_hii);
  for i=1:numel(too_hii)
     ts(i,:)=DATA(xx(i),yy(i),zz(i),:); 
  end
  [v,i] = sort(-1*td(too_hii)); v=-1*v;

  figure
  subplot(1,3,1); plot(tsnr); title('tsnr all voxels')
  ax = subplot(1,3,2); imshow(td(:,:,44)/300); title('tsnr at z=44')
  % zz(i(end)) == 44; v(end) == td(too_hii(i(end))) %  == 319.5
  subplot(1,3,3);  hold on; title('ts of highest tsnr voxels');
  plot(1:50,repmat(max(DATA,[],'all'),1,50),'r','LineWidth',2);
  plot(ts(i([1:5 end]),:)', 'LineWidth',1);  
  hold(ax,'on')
  plot(ax, yy(i([1:5 end])), xx(i([1:5 end])),'r.')
  hold off

  %td(~isfinite(td)) = nan;
  %[v,i] = nanmax(td(:)); [mx,my,mz] = ind2sub(size(MASK), i) % 48,19,45
  % ts=nan(numel(ix), size(DATA,4)); for i=1:numel(ix), ts(i,:)=DATA(ix(i),iy(i),iz(i),:); end
%}

fprintf('# [%s] finished in %.2f\n', datestr(now), stat.calc_dur)
if nargout > 1
   varargout{1} = struct('DATA', DATA,'ALL_MASK', ALL_MASK,...
                         'DX', DX, 'DY', DY, ...
                         'snr', snr, 'tsnr', tsnr);
end
return;
end
