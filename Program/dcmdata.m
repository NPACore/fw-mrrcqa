function [data, info] = dcmdata(P)

[info, err] = dicm_hdr(P); %extended dicom info
if isfield(info,'AcquisitionMatrix')
    nx = double(info.AcquisitionMatrix(1));
    ny = double(info.AcquisitionMatrix(end));
    if isfield(info,'LocationsInAcquisition')
       nz = double(info.LocationsInAcquisition);
    else
       nz = double(info.Private_0019_100a);
    end
    mx = info.Columns/nx;
    my = info.Rows/ny;
    
    TR = info.RepetitionTime; %msec
    data = squeeze(dicomread(info)); % size(data) == [658 658] % prisma
    data = read_mosaic(data,nx,mx,ny,my,nz);
else
    % enhanced dicom
    data = squeeze(dicomread(info));
end
end
