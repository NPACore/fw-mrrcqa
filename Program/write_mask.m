%%%%%%%%
% write out masks used by QA.m/dostats.m. to be used by fast ANTs version.

% 20250821 - init. modifeid dostats.m to write out ALL_MASKS
%%%%%%%%

% load in ALL_MASK -- 4th dim is each mask
load ../outputs/sigstat.mat 
% x=cat(3,maskphan, maskbg, maskalias, mask_noiseroi, mask_pe_noiseroi, mask_ro_noiseroi);
ref = spm_vol('../snr/ref/bullet_phantom_ref.nii.gz');

ref.fname = '../snr/ref/qa_masks.nii'; % single volume
%ref.dim(4)=size(ALL_MASK,4);
rmfield(ref,'pinfo');
ref.dt(1) = spm_type('uint8'); % smallest size
% https://github.com/VUIIS/spm_readwrite_nii
for i =1:size(ALL_MASK,4)
   disp(i)
   ref.n(1)=i;
   spm_write_vol(ref,ALL_MASK(:,:,:,i));
end

% 20250902 - input is shifted! does not match original position
% see dostats.m:220
%   DATA(:,:,ll,i) = circshift(DATA(:,:,ll,i),[dx dy]);
%   mask = circshift(mask,[dx dy]);
%   maskalias = circshift(maskalias,[dx dy]);
dataout = spm_vol('../snr/ref/bullet_phantom_ref.nii.gz');
dataout.fname = '../snr/ref/phantom_recentered_4d.nii'; % single volume
%ref.dim(4)=size(ALL_MASK,4);
rmfield(dataout,'pinfo');
for i =1:size(DATA,4)
   dataout.n(1)=i;
   spm_write_vol(dataout,DATA(:,:,:,i));
end
system(['3dMean -overwrite -prefix ../snr/ref/bullet_phantom_ref_center.nii.gz ',dataout.fname])
