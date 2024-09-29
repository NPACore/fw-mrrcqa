function D = find_all_dicoms(pfolder)
% FIND_ALL_DICOMS -- look through a folder for *IMA, MR*, or *dcm files


  nfile = 0;
  ftypes = {'MR.*', '*.dcm', '*.IMA'}; % dicom file extension. IMA is current Prisma output
  ftype_idx=1;
  
  if !exist(pfolder, 'dir'), error(['given DICOM dir ' pfolder ' does not exist']); end
  while nfile < 1 && ftype_idx<=length(ftypes)
     % fprintf('%d: looking for %s\n', ftype_idx, ftypes{ftype_idx})
     ftype = ftypes{ftype_idx};
     D = dir([pfolder '/' ftype]);
     nfile = size(D,1);
     ftype_idx=ftype_idx+1;
  end
  
  if nfile < 1,
     ls(pfolder),
     error(['no files files like ' strjoin(ftypes,',') ' in ' pfolder]);
  end
end

%!test
%! D = find_all_dicoms('../input/trunc') ;
%! % assert(size(D,1) > 3)
