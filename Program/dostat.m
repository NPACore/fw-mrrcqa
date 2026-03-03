function [stat] = dostat(pfolder,bfig, outdir)
% function [stat] = dostat(pfolder,bfig, outdir)

%{
%% Release memory
%
clear all;
%}
if nargin == 0
   disp('USAGE: dostats /path/to/dicomdir 0 /path/to/savedir')
   disp('  "0" can be "1" to save a figure and mask information')
   disp('  also see run.py (/flywheel/v0/run.py in container)')
   error('bad arguments')
end

calc_start_time = tic;
% load depends if running octave
% see 'pkg install dicom -forge' or e.g. 'yay -S octave-dicom' (needs GDCM lib)
if exist('OCTAVE_VERSION', 'builtin') ~= 0; pkg load dicom image; end

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

%% Pre-set index 
%
ishift = [12 0]; % PE shift <- phantom positioned high due to Siemens pad
hzrng = [13 81]; % Horizontal range of phantom width

noiseroi1 = [2 12; 2 12]; % 4 corner noise ROI (cyan in Fig. 2D)
noiseroi2 = [2 12; 83 93];
noiseroi3 = [83 93; 2 12];
noiseroi4 = [83 93; 83 93];

% Read Out issues will appear as ghosting on the left or right of the image
% RO noise ROI <- central range in PE direction (green in Fig. 2D)
% 20250312 - shift by a pixel
%ro_noiseroi1 = [13 82; 2 12]; %ro_noiseroi2 = [13 82; 83 93];
ro_noiseroi1  = [13 82; 1 12];  ro_noiseroi2 = [13 82; 83 94];

% Phase Encoding issues will appear as aliasing in the top or bottom of the image
% PE noise ROI <- brown area in Fig. 2D
pe_noiseroi1 = [2 12; 13 82];
pe_noiseroi2 = [83 93; 13 82];

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

%% Loading image data
% look for IMA, dcm, or MR* files
D = find_all_dicoms(pfolder);

% dicom information
name = D(1,1).name;
folder = D(1,1).folder;
P = [folder '/' name];
%info = dicominfo(P);
% fprintf('# reading %s\n', P);
[info, err] = dicm_hdr(P); %extended dicom info
% image size and mosaic size
nx = double(info.AcquisitionMatrix(1));
ny = double(info.AcquisitionMatrix(end));
%nz = info.Private_0019_100a;
nz = double(info.LocationsInAcquisition);
mx = info.Columns/nx;
my = info.Rows/ny;

% ep2d mosaic example dims
% 7x7 grid, each with 94x94
% [nx, ny, nz]               ==  94   94  46
% [info.Columns, info.Rows]  == 658  658
% [mx, my]                   ==   7    7

% 4 corner noise ROI
noiseroi = zeros(nx,ny);
noiseroi(noiseroi1(1,1):noiseroi1(1,2), noiseroi1(2,1):noiseroi1(2,2)) = 1;
noiseroi(noiseroi2(1,1):noiseroi2(1,2), noiseroi2(2,1):noiseroi2(2,2)) = 1;
noiseroi(noiseroi3(1,1):noiseroi3(1,2), noiseroi3(2,1):noiseroi3(2,2)) = 1;
noiseroi(noiseroi4(1,1):noiseroi4(1,2), noiseroi4(2,1):noiseroi4(2,2)) = 1;
% RO noise ROI
ro_noiseroi = zeros(nx,ny);
ro_noiseroi(ro_noiseroi1(1,1):ro_noiseroi1(1,2), ro_noiseroi1(2,1):ro_noiseroi1(2,2)) = 1;
ro_noiseroi(ro_noiseroi2(1,1):ro_noiseroi2(1,2), ro_noiseroi2(2,1):ro_noiseroi2(2,2)) = 1;
% PE noise ROI
pe_noiseroi = zeros(nx,ny);
pe_noiseroi(pe_noiseroi1(1,1):pe_noiseroi1(1,2), pe_noiseroi1(2,1):pe_noiseroi1(2,2)) = 1;
pe_noiseroi(pe_noiseroi2(1,1):pe_noiseroi2(1,2), pe_noiseroi2(2,1):pe_noiseroi2(2,2)) = 1;

% 20250409 - BUG! had hardcoded nfile to 4 -- much noisier measures (but ran a lot faster)
%nfile= 4;
nfile = length(D);

% Measurement memory
phansignal = zeros(2, nz,nfile); % 1 - mean; 2 - std
totnoisesignal = zeros(2, nz,nfile);
noisesignal = zeros(2, nz,nfile);
ro_noisesignal = zeros(2, nz,nfile);
pe_noisesignal = zeros(2, nz,nfile);
aliasnoisesignal = zeros(2, nz,nfile);

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
TR = info.RepetitionTime; %msec
cnt = 1;
t = [];
DX = [];
DY = [];

nmasks = 5; % mask, bg, noise, ro, pe
roi_area = zeros(mx, my, nfile, nmasks);
mask_thresh = zeros(mx, my, nfile); % collecting mnval

% for each time point. first used as reference already
for i=1:nfile
    % dicom  file
    name = D(i,1).name;
    folder = D(i,1).folder;
    P = [folder '/' name]; 
    % read DICOM header including CSA information
    info = dicominfo(P);
    [s, err] = dicm_hdr(P);
    if bfig==1, disp([name ' - ' num2str(s.AcquisitionNumber) '/' num2str(s.InstanceNumber) ]); end
    % B0 shim value
    [shimvalues,strbuff] = readshimvalues(P);
    %disp([num2str(s.InstanceNumber) ': ' num2str(shimvalues)]);
    % image
    data = dicomread(info); % size(data) == [658 658]
    %figure(1); imagesc(data); axis image; colormap(gray); drawnow;
    % de-mosaic
    icnt = 1;
    for jj=1:my % row
        for ii=1:mx % column
            ll = ii + (jj-1)*mx; % z
            if ll > nz, break; end

            ir = (ii-1)*nx+1:ii*nx;
            jr = (jj-1)*ny+1:jj*ny;

            % data in 4D
            if cnt == 1
                DATA(:,:,ll,i) = circshift(data(jr,ir),ishift);
                DATA(:,1,ll,i) = DATA(:,2,ll,i);
                dataslice = DATA(:,:,ll,i);
            else
                DATA(:,:,ll,i) = circshift(data(jr,ir),ishift);
                DATA(:,1,ll,i) = DATA(:,2,ll,i);
                DATA(:,:,ll,i) = circshift(DATA(:,:,ll,i),[DX(icnt) DY(icnt)]);
                dataslice = DATA(:,:,ll,i);
            end

            % mask per slice
            if cnt==1
                tmp = DATA(:,:,ll,i);
                mnval = mean(mean(DATA(:,:,ll,i),1),2);
                mask_thresh(ii,jj,i) = mnval;

                sdval = std(std(DATA(:,:,ll,i),[],1),[],2);
                mask = zeros(nx,ny);
    
                afactor = 1.2;

                mask = mask(:); tmp = tmp(:); I = find(tmp > afactor*mnval);
                mask(I) = 1; mask = reshape(mask,nx,ny);
                maskalias = circshift(mask, [nx/2 0]);
                maskalias = maskalias - and(maskalias, mask);

                %centering
                cemask = imerode(mask, sec);
                [I,J] = find(cemask >= 1);
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
                    % noise ROI
                    if 0
                    if icnt==1
                        ro_noiseroi = circshift(ro_noiseroi,[dx dy]);
                        noiseroi = circshift(noiseroi,[dx dy]);
                        pe_noiseroi = circshift(pe_noiseroi,[dx dy]);
                    end
                    end
                end

                if bfig==1
                    figure(2); subplot(2,2,1); imagesc(log(DATA(:,:,ll,i)),[0 10]); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,2); imagesc(mask); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,3); imagesc(maskalias); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,4); imagesc(noiseroi+2*ro_noiseroi+4*pe_noiseroi); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);

                    if icnt==1, set(gcf, 'Windowstyle', 'docked'); saveas(gcf,fullfile(outdir,'mask_rois.png'),'png'); end
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
            if ~isempty(getenv('QA_SAVE_IMAGES'))
               ALL_MASK(:,:,ll, idx.phan_erode) = reshape(maskphan1, nx,ny);
               ALL_MASK(:,:,ll, idx.bg)         = reshape(maskbg1,nx,ny);
               ALL_MASK(:,:,ll, idx.alias)      = reshape(maskali1,nx,ny);
               ALL_MASK(:,:,ll, idx.noise)      = reshape(noiseroi1,nx,ny);
               ALL_MASK(:,:,ll, idx.readout)    = reshape(ro_noiseroi1,nx,ny);
               ALL_MASK(:,:,ll, idx.phaseenc)   = reshape(pe_noiseroi1,nx,ny);
            end

            % collect area stats
            roi_area(ii, jj, i, :) = [sum(maskphan1), sum(maskbg1), sum(noiseroi1), sum(ro_noiseroi1), sum(pe_noiseroi1)];
            icnt = icnt+1;
        end % mx as ii
    end % my as jj

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
   
    figure(3); subplot(4,1,1); plot(phansignal(1,1:i*nz)./noisesignal(2,1:i*nz),'r','LineWidth',2); axis tight; ylabel('SNR');
    figure(3); subplot(4,1,2); plot(totnoisesignal(1,1:i*nz)./noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('Bankgraound');
    figure(3); subplot(4,1,3); plot(aliasnoisesignal(1,1:i*nz)./noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('Aliasing');
    figure(3); subplot(4,1,4); plot(noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('corner noise');
    %figure(3); subplot(6,1,5); plot(ro_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('ro noise');
    %figure(3); subplot(6,1,6); plot(pe_noisesignal(2,1:i*nz),'b','LineWidth',2); axis tight; ylabel('pe noise');
    end
    
    t = [t TR*(cnt-1)];
    cnt = cnt + 1;
end

%% Statistics
%
% signal size is (2, 46, 200) - mean&sd measure per slice per timepoint
snr = phansignal(1,:)./noisesignal(2,:);
alias = aliasnoisesignal(1,:)./noisesignal(2,:);
background = totnoisesignal(1,:)./noisesignal(2,:);
noise = noisesignal(2,:);

tsnr = zeros(1,nx*ny*nz);
DD = reshape(DATA,nx*ny*nz,nfile);
for i=1:nx*ny*nz
    tsnr(1,i) = mean(DD(i,:))/std(DD(i,:));
end
I = find(MASK(:)==1);

[snrn,snrx] = hist(snr,120);
[aliasn,aliasx] = hist(alias,120);
[backgroundn,backgroundx] = hist(background,120);
[noisen,noisex] = hist(noise,120);
[tsnrn,tsnrx] = hist(tsnr(I),120);

if bfig==1
%{
H=figure(4); p=subplot(1,4,1); p.YLabel.String='SNR'; hold on; histogram(snr,120); set(H,'Name', pfolder); hold off;
figure(4); p=subplot(1,4,2); p.YLabel.String='Aliasing'; hold on;  histogram(alias,120); hold off;
figure(4); p=subplot(1,4,3); p.YLabel.String='Background'; hold on;  histogram(background,120); hold off;
figure(4); p=subplot(1,4,4); p.YLabel.String='Noise'; hold on;  h=histogram(noise,120); hold off;
%}
H=figure(4); p=subplot(1,5,1); ylabel('SNR'); hold on; plot(snrx,snrn,'LineWidth',2); set(H,'Name', pfolder); axis([0 500 0 400]); hold off;
  figure(4); p=subplot(1,5,2); ylabel('Aliasing'); hold on;  plot(aliasx,aliasn,'LineWidth',2); axis([0 40 0 300]);   hold off;
  figure(4); p=subplot(1,5,3); ylabel('Background Offset'); hold on;  plot(backgroundx,backgroundn,'LineWidth',2); axis([0 40 0 300]);   hold off;
  figure(4); p=subplot(1,5,4); ylabel('Absolute Noise'); hold on;  plot(noisex,noisen,'LineWidth',2); axis([0 10 0 400]);   hold off;
  figure(4); p=subplot(1,5,5); ylabel('tSNR'); hold on;  plot(tsnrx,tsnrn,'LineWidth',2);  hold off;
end

%% Report
%
stat = struct;
[M,I] = max(snrn); stat.snrpk = snrx(I);
[M,I] = max(aliasn); stat.aliaspk = aliasx(I);
[M,I] = max(backgroundn); stat.bkoffpk = backgroundx(I);
[M,I] = max(tsnrn); stat.tsnrpk = tsnrx(I);

stat.shim = shimvalues;

stat.snr = [snrn; snrx];
stat.alias = [aliasn; aliasx];
stat.bkoff = [backgroundn; backgroundx];
stat.absnoise = [noisen; noisex];
stat.tsnr = [tsnrn; tsnrx];

% sum of first 2 dims (x-z,y-z), average of time, value per mask, bg, noise, ro, pe
% TODO: why x-z and y-z ? WF: maybe dont understand the inner most loop
stat.maskVol_mbnrp = mean(squeeze(sum(squeeze(sum(roi_area,1)),1)));
stat.mask_thresh_mean = mean(mask_thresh(:));
stat.mask_thresh_sd = std(mask_thresh(:));

stat.dicominfo = s;
stat.date = stat.dicominfo.StudyDate;

stat.calc_dur = toc(calc_start_time);

%% Saving
% 20251211 - moved from QC.m to here
if nargin > 2
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
    maskphan = mask;
    maskbg = 1 - mask;
    mask_noiseroi = noiseroi;
    mask_ro_noiseroi = ro_noiseroi;
    mask_pe_noiseroi = pe_noiseroi;
    matfname = fullfile(outdir, 'sigstat.mat');


    fprintf('# saving %s\n', matfname)
    save(matfname, 'DATA','t',...
        'maskphan','maskbg','maskalias','mask_noiseroi','mask_ro_noiseroi','mask_pe_noiseroi',...
        'phansignal','totnoisesignal','aliasnoisesignal','noisesignal','ro_noisesignal','pe_noisesignal', ...
         'roi_area', 'MASK','ALL_MASK', 'idx', ...
         'DX','DY', ... DX all 0, DY all -1
         'ishift', 'hzrng', ... hzrng not used!
         'stat', ... final output
         ... signals and mean/std calcs
         'snr', 'phansignal', ...
         'tsnr', 'tsnrx','tsnrn', ...
         'alias',  'aliasnoisesignal',...
         'background','totnoisesignal', ...
         'noise', 'noisesignal' ...
        );
else
    fprintf('# not saving mask data, set QA_SAVE_IMAGES to save\n')
end

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
return;
