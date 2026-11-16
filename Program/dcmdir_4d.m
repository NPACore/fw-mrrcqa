function [DATA, info] = dcmdir_4d(pfolder, verbose)
    % DCMDIR_4D - read dicom folder into 4D dataset
    % output 'info' has last dicom's header AND 'extra', 'files', 'instanceNumbers' field
    if nargin<2, verbose=0; end
    readtime = tic;

    fprintf('# [%s] searching %s\n', datestr(now), pfolder)
    % look for IMA, dcm, or MR* files
    D = find_all_dicoms(pfolder);
    fprintf('# [%s] found %d dicoms\n', datestr(now), length(D))
    nfile = length(D);
    % 20261114 - debugging overwrite with environment variable
    if ~isempty(getenv('MAXTIMEPOINTS'))
        nfile=min(nfile,str2num(getenv('MAXTIMEPOINTS')));
        fprintf("# NOTE: truncating to read first %d only (MAXTIMEPOINTS)\n", nfile);
    end    
    instanceNumbers=zeros(nfile,1);

    for i=1:nfile
        % dicom  file
        idv_dcmread = tic;
        name = D(i,1).name;
        folder = D(i,1).folder;
        P = [folder '/' name]; 
        % read DICOM header including CSA information
        info = dicominfo(P);
        %[s, err] = dicm_hdr(P);

        % enhanced dicom or mosaic dicom?
        instanceNumbers(i) = info.InstanceNumber;

        %disp([num2str(s.InstanceNumber) ': ' num2str(shimvalues)]);
        % image
        data = squeeze(dicomread(info)); % size(data) == [658 658] % prisma
                                         %figure(1); imagesc(data); axis image; colormap(gray); drawnow;

        %% set dims once, allocated full DATA
        if i==1
          if size(size(data),2) == 2 % Prisma/VE (v. Terra @ XA60 )
              nx = double(info.AcquisitionMatrix(1));
              ny = double(info.AcquisitionMatrix(end));
              if isfield(info,'LocationsInAcquisition')
                nz = double(info.LocationsInAcquisition);
              else
                nz = info.Private_0019_100a;
              end
              % mx and my only used for read_mosaic. 
              % TODO: used for roi_area and mask_thres (erronously?)
              mx = info.Columns/nx;
              my = info.Rows/ny;
              TR = info.RepetitionTime; %msec
              % image size and mosaic size
          else % XA30 / enhanced dicom (TerraX)
              [nx,ny,nz] = size(data);
              mx = 1;
              my = 1;
              TR = info.SharedFunctionalGroupsSequence.Item_1.MRTimingAndRelatedParametersSequence.Item_1.RepetitionTime;
          end
          DATA = zeros(nx,ny,nz,nfile);
        end

        %% read individual data
        if size(size(data),2) == 2 % Prisma/VE (v. Terra @ XA60 )
            % image size and mosaic size
            DATA(:,:,:,i) = read_mosaic(data,nx,mx,ny,my,nz);
            acqtimes(i) = str2double(info.AcquisitionTime);
        else % XA30 / enhanced dicom (TerraX)
            DATA(:,:,:,i) = data;
            acqtimes(i) = str2double(info.AcquisitionDateTime);
        end

        % feedback when debugging. what dicom are we reading in what order and how long does it take
        if verbose==1
            idv_dcmread=toc(idv_dcmread);
            fprintf('% 3d acq# % 3d inst# % 3d/% 3d (acq %.2f) in %.2fs [%s]\n', ...
                    i, info.AcquisitionNumber, info.InstanceNumber, nfile, acqtimes(i), idv_dcmread,name);
        end
    end

    % std not implemented for uint16
    if isa(DATA, 'uint16')
        DATA = double(DATA);
    end

    readtime_out = toc(readtime);
    fprintf('# [%s] read dicoms %dx%dx%dx%d in %.2fs\n', datestr(now), size(DATA), readtime_out);

    % make sure dicoms are ordered
    % could also use InstanceNumber
    [v, o] = sort(instanceNumbers);
    ooo = diff(o); % out of order?
    if max(abs(ooo)) ~= 1 || min(ooo) < 1
        fprintf('# NOTE: dicom file order is not acqtime order. rearranging\n')
        DATA = DATA(:,:,:,o);
        instanceNumbers = instanceNumbers(o);
        D = D(o);
    end
    % uniform/harmonized VE11/XA60 dicom header info
    % in case we want it again -- don't need to figure out what we have
    % also see info.SoftwareVersion
    info.extra=struct('mx', mx, 'my', my, 'TR', TR);
    info.files = D;
    info.instanceNumbers = instanceNumbers;

end
