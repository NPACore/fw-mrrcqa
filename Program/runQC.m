%
% Daily QA w/ Siemens phantom w/ 64ch head-neck coil
% @chm - 08/13/2024
% @wf  - 20240821 - as function for matlab runtime
%
function runQC(dicom_folder, tlabel)
% Study folder information
reportstatgrp = [];
bfig = 0;
tpfolder = dicom_folder;
fprintf('# starting "dostat" %s\n', system('date')),tic;
[stat] = dostat(tpfolder,tlabel,bfig);
fprintf('# finished "dostat" %s', system('date'))
total_readtime=toc,

stat.tlabel = tlabel;
stat.dicominfo.StudyDescription;
stat.dicominfo.StudyDate;
stat.dicominfo.StationName;
stat.dicominfo.SequenceName;
stat.dicominfo.ProtocolName;
stat.dicominfo.CoilString;
stat.dicominfo.ImageTypeText;
disp(stat);

reportstat = [stat.snrpk stat.aliaspk stat.bkoffpk stat.tsnrpk stat.shim(1:end-1) stat.shim(end)/1000];
reportstatgrp = [reportstatgrp; reportstat];

txlabel = {'SNR','ALIAS','BGOff','tSNR'};
figure(1); subplot(3,1,1); bar(txlabel,reportstatgrp(:,1:4)); legend(tlabel);
txlabel = {'X','Y','Z','X2','Y2','Z2','XY','S2'};
figure(1); subplot(3,1,2); bar(txlabel,reportstatgrp(:,5:end-1)); legend(tlabel);
figure(1); subplot(3,1,3); bar(reportstatgrp(:,end:end)); legend('B0');
end
