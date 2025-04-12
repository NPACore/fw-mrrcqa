#!/usr/bin/env octave
#
# entrypoint for octave + docker/singularity/gear
#

addpath(fileparts(mfilename('fullpath')));

%% handle input arguments
dicom_dir = argv{1};
if length(argv) < 2
  output_dir = 'outputs';
else
  output_dir = argv{2};
end

%% Main
dcm_stats = dostat(dicom_dir, 0);

%% Write ouputs
% NB. will not make recursive output dir?
if ~exist(output_dir,'dir'), mkdir(output_dir); end

json_outfile = fullfile(output_dir, 'stats.json');

%dcm_stats_write = rmfield(dcm_stats,'bufstr');
json_str = jsonencode(dcm_stats);
fprintf('saving %d chars of json to %s\n', length(json_str), json_outfile);
fid = fopen(json_outfile,'w');
fprintf(fid, '%s', json_str);
fclose(fid);

% 20250409 - removed QC plots (bar.png)
%image_outfile = fullfile(output_dir, 'bars.png');
%fprintf('saving bar figure to %s\n', image_outfile);
%f = figure('visible','off');
%plotQC(dcm_stats,'', f);
%saveas(f, image_outfile);
