%
% Daily QA w/ Siemens phantom w/ 64ch head-neck coil
% @chm - 08/13/2024
% @wf  - 20240821 - as function for matlab runtime
%
function stat = runQC(dicom_folder, tlabel, bfig)
% Study folder information
if nargin < 3, bfig = 0; end
if nargin < 2, tlabel = ''; end

tpfolder = dicom_folder;
fprintf('# starting "dostat" %s\n', system('date')),tic;
[stat] = dostat(tpfolder, bfig);
fprintf('# finished "dostat" %s', system('date'))
total_readtime=toc,
% on small laptop, takes 40 min to run
% # finished "dostat" total_readtime = 2452.7
% profexplore
%  runQC: 1 calls, 2430.406 total, 0.012 self
%    dostat: 1 calls, 2430.377 total, 2201.059 self
%      1) std: 461748 calls, 85.922 total, 12.796 self
%      2) mean: 461748 calls, 45.961 total, 33.255 self
%      3) readshimvalues: 200 calls, 44.809 total, 32.325 self
%      4) dicm_hdr: 201 calls, 28.457 total, 1.506 self
%      5) dicominfo: 200 calls, 18.322 total, 18.322 sel

stat.tlabel = tlabel;
% save(fullfile(dicom_folder, 'stats.mat'), 'stat')

plotQC(stat, tlabel)
end
