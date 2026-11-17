function [stat, varargout] = dostat_xa60(pfolder,bfig, outdir)

if nargin == 0
   disp('USAGE: dostats /path/to/dicomdir 0 /path/to/savedir')
   disp('  "0" can be "1" to save a figure and mask information')
   disp('  also see run.py (/flywheel/v0/run.py in container)')
   disp('  env: MRRCQA_VERSION, QA_SAVE_IMAGES, MAXTIMEPOINTS')
   error('bad arguments')
end

calc_start_time = tic;
% load depends if running octave
% see 'pkg install dicom -forge' or e.g. 'yay -S octave-dicom' (needs GDCM lib)
if exist('OCTAVE_VERSION', 'builtin') ~= 0; pkg load dicom image; end

%% read data
[~,hostname] = system('hostname'); hostname=strtrim(hostname);
fprintf('# running as %s@%s\n', getenv('USER'), hostname)
%% Loading image data
[DATA, info] = dcmdir_4d(pfolder); % 2s per file!
[nx, ny, nz, nfile] = size(DATA);

% B0 shim value - read once (20261114), should be same for all in series
P = fullfile(info.files(1).folder, info.files(1).name);
[dicominfo, err] = dicm_hdr(P);
[shimvalues, shimmode, strbuff, GradSensitivity] = readshimvalues(P);
% B1 shim values. resuse strbuff from shimvalues
b1vals = readB1values(strbuff);


%% Pre-set values
stat = [];
afactor = 1.2; %  dicom >= mean + afactor ==> phantom data
% see: imagesc(sum(data,3))

% PE shift <- phantom positioned high due to Siemens pad
ishift = [12 0];  % used for initial volume

bwidth = 12; % border width for
             % noise (4 corner boxes), read out (left/right rectangles), and phase encode (top/bottom rects)

% 20261114 - prisma QC acq is 94x94. TerraX QC acq is currently 128x128
%            cannot test on enhanced dicom b/c Prisma will eventually also update to XA
% what kind of phantom do we have? default to prisma
isTerraX = 0;
if nx > 96, isTerraX = 1; end
         
% TerraX "Pink" phantom sits in center of bore. no need to shift
% phantom is also bigger. readout noise box will be thinner
if isTerraX
    ishift = [0 0];
    bwidth = [8 10]; % ro width, pe height
    % intensities are very near center. when low int meants edge, get bad mask
    afactor = 1.2;
end

% make a move if we're plotting each frame
if bfig
    mkdir(outdir) % make sure we have output
    vidwrite = fullfile(outdir, 'masks_slices.avi');
else
    vidwrite = ''; % dont save
end

%% make masks
example_volume = mean(DATA,4);
% use example volume to adjust center of phantom (DX,DY)
% and create eroded mask (and vert/2 wrapped alias noise mask)
% TODO: maybe used the averaged over time mask
[ex_vol_shifted, mask3d, maskalias3d, DX, DY] = ...
    center_to_mask(example_volume, ishift, afactor, bfig, vidwrite);

% read out noise rois top and bottom border srips
% phase encode noise rois left and right border strips
% noise roi is 4 corners
[noiseroi, ro_noiseroi, pe_noiseroi] = make_masks(bwidth, nx, ny);
% masks = noiseroi + 2^2*ro_noiseroi+2^3*pe_noiseroi; masks(masks==0)=NaN;

%% Looping files
% for each time point. first used as reference already
for i=1:nfile
    % shift data so phantom is always centered
    % based on example data that also generated phantom and alias mask
    % data then mathes 4corner, pe, and ro noise masks
    % NB. circshift wont take a 3d vector
    for ll=1:nz
        DATA(:,:,ll,i) =  circshift(DATA(:,:,ll,i),[DX(ll) DY(ll)]);
    end
end
ALL_MASKS = struct(...
    'alias',   maskalias3d, ...
    'phan',    mask3d, ...
    'tot',     1-mask3d, ...
    'corners', ones(size(mask3d)).*noiseroi, ...
    'ro',      ones(size(mask3d)).*ro_noiseroi, ...
    'pe',      ones(size(mask3d)).*pe_noiseroi);

noise_mask_names = fieldnames(ALL_MASKS);
noisesignals = struct();
for fni=1:length(noise_mask_names)
    fn=noise_mask_names{fni};
    noisesignals.(fn) = vec_mu_sigma(DATA,ALL_MASKS.(fn),[1 2]);
end

% matching original names
aliasnoisesignal = noisesignals.alias;
phansignal       = noisesignals.phan;
totnoisesignal   = noisesignals.tot;
noisesignal      = noisesignals.corners; % NB. singular name of plur structure name!
ro_noisesignal   = noisesignals.ro;
pe_noisesignal   = noisesignals.pe;

% reorg timepoint plots

% Plot dynamic signals
if bfig==1
    f=figure(3); clf(3);
    f.Position=[0 0 600 800];
    suptitle('slice@time measures');
    for fni =1:length(noise_mask_names)
        fn=noise_mask_names{fni};
        musigma = noisesignals.(fn);
        subplot(8,1,fni); plot(musigma(1,:) ./ musigma(2,:),'b','LineWidth',2); axis tight; ylabel(fn); 
    end

    % tiempoints - R2019: cant use vector positions
    hold on
    arrayfun(@(x) xline(x,'-r'), (1:size(DATA,4))*nz);
    xlabel('mean/std at each z slice repeated over time')


    % subplotu(8,1,7) blank. taken by below
    s7=subplot(8,1,8); yyaxis left;
    for fni =1:length(noise_mask_names)
        fn=noise_mask_names{fni};
        nvox_z = squeeze(sum(ALL_MASKS.(fn),[1 2]));
        nvox_z_norm = nvox_z ./ max(nvox_z,[],'all');
        plot(nvox_z_norm); hold on;
    end


    ylabel('nvoxels/total'); title('voxels in masks');
    yyaxis right; hold on; plot(DX, 'r');plot(DY, 'g'); ylabel('recenter distance')
    legend({noise_mask_names{:} 'DX' 'DY'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    s7.Position(4) = s7.Position(4)+.1;
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

I = find(ALL_MASKS.phan(:)==1);

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

% don't save these: 2*120 histbin value+idx that aren't that useful out of context?
%stat.snr = [snrn; snrx];
%stat.alias = [aliasn; aliasx];
%stat.bkoff = [backgroundn; backgroundx];
%stat.absnoise = [noisen; noisex];
%stat.tsnr = [tsnrn; tsnrx];

stat.dicominfo = dicominfo;
stat.date = stat.dicominfo.StudyDate;

% 2026-03-03 - max value clipping?
stat.percent_voxels_max = 100*nnz(DATA == max(DATA(:)))/numel(DATA);
masked = DATA.*ALL_MASKS.phan; % TODO: this already exists?
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

    fprintf('# [%s] saving images to %s\n', datestr(now), matfname)
    save(matfname, 'DATA',...
        'phansignal','totnoisesignal','aliasnoisesignal','noisesignal','ro_noisesignal','pe_noisesignal', ...
         'ALL_MASKS',...
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
   varargout{1} = struct('DATA', DATA,'ALL_MASKS', ALL_MASKS,...
                         'DX', DX, 'DY', DY, ...
                         'snr', snr, 'tsnr', tsnr);
end
return;
end
