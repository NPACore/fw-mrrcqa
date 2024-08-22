#!/usr/bin/env octave
#
# entrypoint for octave + docker/singularity/gear
#

addpath(fileparts(mfilename('fullpath')));
if ~exist('outputs','dir'), mkdir outputs; end
dicom_dir = argv{1};
if length(argv) < 2
  output_dir = 'outputs';
else
  output_dir = argv{2}';
end

dcm_stats = dostat(dicom_dir, 0);
fid = fopen(fullfile(output_dir, 'stats.json'),'w');
%dcm_stats_write = rmfield(dcm_stats,'bufstr');
fwrite(fid, jsonencode(dcm_stats));
fclose(fid);

f = figure('visible','off');
plotQC(dcm_stats,'', f);
saveas(f, full_file(output_dir, 'bars.png'));
