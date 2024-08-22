function [stat] = dostat(pfolder,bfig)
% function [stat] = dostat(pfolder,bfig)

%{
%% Release memory
%
clear all;
%}

% load depends if running octave
% see 'pkg install dicom -forge' or e.g. 'yay -S octave-dicom' (needs GDCM lib)
if exist('OCTAVE_VERSION', 'builtin') ~= 0, pkg load dicom; end

stat = [];

%% Pre-set index 
%
ishift = [12 0]; % PE shift <- phantom positioned high due to Siemens pad
hzrng = [13 81]; % Horizontal range of phantom width

noiseroi1 = [2 12; 2 12]; % 4 corner noise ROI (cyan in Fig. 2D)
noiseroi2 = [2 12; 83 93];
noiseroi3 = [83 93; 2 12];
noiseroi4 = [83 93; 83 93];

ro_noiseroi1 = [13 82; 2 12]; % RO noise ROI <- central range in PE direction (green in Fig. 2D)
ro_noiseroi2 = [13 82; 83 93];

pe_noiseroi1 = [2 12; 13 82]; % PE noise ROI <- brown area in Fig. 2D
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
%
if !exist(pfolder, 'dir'), error(['given DICOM dir ' pfolder ' does not exist']); end
nfile = 0;
ftypes = {'*.IMA', 'MR.*', '*.dcm'}; % dicom file extension. IMA is current Prisma output
ftype_idx=1;

while nfile < 1 && ftype_idx<length(ftypes)
   ftype = ftypes{ftype_idx};
   D = dir([pfolder '/' ftype]);
   nfile = size(D,1);
   ftype_idx=ftype_idx+1;
end
if nfile < 1, error(['no files files like ' strjoin(ftypes,',') ' in ' pfolder]); end
% dicom information
name = D(1,1).name;
folder = D(1,1).folder;
P = [folder '/' name];
%info = dicominfo(P);
[info, err] = dicm_hdr(P); %extended dicom info
% image size and mosaic size
nx = double(info.AcquisitionMatrix(1));
ny = double(info.AcquisitionMatrix(end));
%nz = info.Private_0019_100a;
nz = double(info.LocationsInAcquisition);
mx = info.Columns/nx;
my = info.Rows/ny;

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

nfile= 4;
% Measurement memory
phansignal = zeros(2, nz,nfile); % 1 - mean; 2 - std
totnoisesignal = zeros(2, nz,nfile);
noisesignal = zeros(2, nz,nfile);
ro_noisesignal = zeros(2, nz,nfile);
pe_noisesignal = zeros(2, nz,nfile);
aliasnoisesignal = zeros(2, nz,nfile);

% Memory
DATA = zeros(nx,ny,nz,nfile);
MASK = zeros(nx,ny,nz);

%% Looping files
%
TR = info.RepetitionTime; %msec
cnt = 1;
t = [];
%for i=1:nfile %1st - reference
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
    data = dicomread(info);
    %figure(1); imagesc(data); axis image; colormap(gray); drawnow;
    % de-mosaic
    for jj=1:my % row
        for ii=1:mx % column
            ll = ii + (jj-1)*mx;
            if ll > nz, break; end

            ir = (ii-1)*nx+1:ii*nx;
            jr = (jj-1)*ny+1:jj*ny;

            % data in 4D
            DATA(:,:,ll,i) = circshift(data(jr,ir),ishift);
            dataslice = DATA(:,:,ll,i);

            % mask per slice
            if cnt==1
                tmp = DATA(:,:,ll,i);
                mnval = mean(mean(DATA(:,:,ll,i),1),2);
                sdval = std(std(DATA(:,:,ll,i),[],1),[],2);
                mask = zeros(nx,ny);
    
                mask = mask(:); tmp = tmp(:); I = find(tmp > mnval);
                mask(I) = 1; mask = reshape(mask,nx,ny);
                maskalias = circshift(mask, [nx/2 0]);
                maskalias = maskalias - and(maskalias, mask);
    
                if bfig==1
                    figure(2); subplot(2,2,1); imagesc(log(DATA(:,:,ll,i)),[0 10]); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,2); imagesc(mask); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,3); imagesc(maskalias); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
                    figure(2); subplot(2,2,4); imagesc(noiseroi+2*ro_noiseroi+4*pe_noiseroi); axis image; colormap(jet); title(['slice = ' num2str(ll) '/' num2str(nz)]);
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
        end
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

%% Saving
%
if 0
    maskphan = mask;
    maskbg = 1 - mask;
    mask_noiseroi = noiseroi;
    mask_ro_noiseroi = ro_noiseroi;
    mask_pe_noiseroi = pe_noiseroi;
    matfname = [pfolder '/sigstat.mat'];
    save(matfname, 'DATA','t',...
        'maskphan','maskbg','maskalias','mask_noiseroi','mask_ro_noiseroi','mask_pe_noiseroi',...
        'phansignal','totnoisesignal','aliasnoisesignal','noisesignal','ro_noisesignal','pe_noisesignal');
end

%% Statistics
%
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
H=figure(4); p=subplot(1,5,1); p.YLabel.String='SNR'; hold on; plot(snrx,snrn,'LineWidth',2); set(H,'Name', pfolder); axis([0 500 0 400]); hold off;
figure(4); p=subplot(1,5,2); p.YLabel.String='Aliasing'; hold on;  plot(aliasx,aliasn,'LineWidth',2); axis([0 40 0 300]);   hold off;
figure(4); p=subplot(1,5,3); p.YLabel.String='Background Offset'; hold on;  plot(backgroundx,backgroundn,'LineWidth',2); axis([0 40 0 300]);   hold off;
figure(4); p=subplot(1,5,4); p.YLabel.String='Absolute Noise'; hold on;  plot(noisex,noisen,'LineWidth',2); axis([0 10 0 400]);   hold off;
figure(4); p=subplot(1,5,5); p.YLabel.String='tSNR'; hold on;  plot(tsnrx,tsnrn,'LineWidth',2);  hold off;
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

stat.dicominfo = s;
stat.date = stat.dicominfo.StudyDate;

return;
