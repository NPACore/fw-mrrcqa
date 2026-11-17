function [DATA, mask3d, maskalias3d, DX, DY] = center_to_mask(volume3d, ishift, afactor, bfig, vidwrite)
    if size(size(volume3d)) ~= 3
        warning('center_to_mask wants a 3d volume! hoping mean is what you want')
        volume3d = mean(volume3d,4);
    end
    [nx,ny,nz]=size(volume3d);
    DATA = volume3d;
    total_mean = mean(volume3d,'all');
    DX = [ishift(1)]; DY= [ishift(2)];

    % nargin < 4 % create figure
    if ~exist('bfig','var'), bfig=0; end
    % nargin < 5 % video output file name
    if ~exist('vidwrite','var'),vidwrite='';end
    % open vidoe for writing
    if ~isempty(vidwrite)    
        vidwrite = VideoWriter(vidwrite); % 'MPEG-4' only for win/macos :(
        vidwrite.FrameRate = 5;  % frames per second
        open(vidwrite);
    end

    % structuring element for erosion
    try
      se = strel('disk', 3);  % mask (values > 1.2 * mean)
      sec = strel('disk', 7); % centering mask
    catch
      % NB. octave does not support MATLABs default n=4 (line structuring elements)
      % see mask_structuring_elements.m
      cached_se = fullfile(fileparts(mfilename),'mask_structuring_elements.mat');
      if ~ exist(cached_se, 'file'), error(cached_se, ' doesnt exist!?'); end
      load(cached_se, 'sec','se');
      warning(['using cached se and sec from ', cached_se])
    end

    % 20261114 - BUG? was not previously tracking per slice position of mask
    mask3d=zeros(size(DATA));
    maskalias3d=zeros(size(DATA));;

    for ll=1:nz
        % data in 4D
        % setup pre-shift
        this_shift = [DX(end) DY(end)];
        DATA(:,:,ll) = circshift(DATA(:,:,ll),this_shift);
        DATA(:,1,ll) = DATA(:,2,ll);

        % mask per slice. per-slice centers DX,DY only calculated on first timepoint
        tmp = DATA(:,:,ll);
        %mnval = mean(mean(tmp,1),2); % bad circles
        mnval = mean(tmp,'all'); % no better
        % mnval = total_mean; % worse
        % this was min value per voxel?
        %mask_thresh(ii,jj,i) = mnval;
        
        sdval = std(std(tmp,[],1),[],2); % sd of sd
        sdval_full = std(tmp(:));
        mask = zeros(nx,ny);
        
        I = find(tmp > afactor*mnval);

        % overloading plotting bool. if plotting also print per slice stats
        mn_std_rat = mnval ./ sdval_full;
        if bfig
            fprintf('# slice %d/%d: mn/sd=%.2f (%.2f/%.2f) v. factor %.2f; nvox mask=%d\n',...
              ll, nz, mn_std_rat, mnval,sdval_full, afactor, length(I));
        end
        if mn_std_rat > 1.5 && mnval < 20
            fprintf('# WARNING: @ slice %d/%d: too much noise (%.2f) with too small mean(%.2f). no data?\n', ...
                   ll,nz,mn_std_rat, mnval)
            DX = [DX DX(end)];
            DY = [DY DX(end)];
            % mask and maskatlias stay zero for this 'll'
            continue
        end
        
        
        mask(I) = 1;
        mask=imfill(mask, 'holes');

        %% Fit a circle
        % Get outer boundary (ignore holes)
        % n objects-by-1 cell: n boundary pixels-by-(row,col) coord (clockwise)
        B = bwboundaries(mask, 'noholes');
        [~,idx] = max(cellfun(@length,B)); % overkill, likely only one object
        b = B{idx};

        % Fit circle via matrix division
        x = b(:,2);
        y = b(:,1);
        p = [x y ones(size(b,1))] \ -(x.^2 + y.^2);

        % Circle parameters
        cx = -p(1)/2;
        cy = -p(2)/2;
        %r  = sqrt(cx^2 + cy^2 - p(3));
        r = max(hypot(x-cx, y-cy));
       

        % Generate filled circle mask
        [X,Y] = meshgrid(1:size(mask,2), 1:size(mask,1));
        circleMask = (X-cx).^2 + (Y-cy).^2 <= r^2;
        mask_holey = mask;
        mask = circleMask;

        %% Alias noise mask
        % split the circle by wrapping around top/bottom
        maskalias = circshift(mask, [nx/2 0]);
        % and remove any overlap with existing mask
        maskalias = maskalias - and(maskalias, mask);
        % both will be reorded and shifted separetly
        
        %%centering
        cemask = imerode(mask, sec);
        [I,J] = find(cemask >= 1);
        
        mask_nvox = sum(mask,'all');
         % empty mask -- no data.
        if isempty(I)
            fprintf('WARNING @i=%03d, slice=%03d: no values gt 1.2*mean (m=%.2f)\n',...
                i, ll, mnval);
            DX = [DX DX(end)];
            DY = [DY DX(end)];
            % mask and maskatlias stay zero for this 'll'
            continue
        end

        % find center
        I0 = ceil(mean(I));
        J0 = ceil(mean(J));
        dx = nx/2+1 - I0;
        dy = ny/2+1 - J0;
        % NOTE: prev DX already applied at start
        DX = [DX dx+DX(end)];
        DY = [DY dy+DY(end)];
        
        emask = imerode(mask, se);
        emaskalias = imerode(maskalias, se);
        
        if 1 % recenter
            mask = emask;
            maskalias = emaskalias;
            
            % centering
            % NOTE: shift is additional
            DATA(:,:,ll) = circshift(DATA(:,:,ll),[dx dy]);
            mask = circshift(mask,[dx dy]);
            mask_holey = circshift(mask_holey,[dx dy]);
            maskalias = circshift(maskalias,[dx dy]);
        end
        
        if bfig==1
            %stitle=['t = ' num2str(i) ' slice = ' num2str(ll) '/' num2str(nz)]
            stitle=sprintf('slice %02d/%d', ll, nz);
            vidfig=figure(2);
            log_data =log(DATA(:,:,ll));
            subplot(2,2,1); imagesc(log_data,[0 10]); axis image; colormap(jet);
              title({stitle, sprintf('mean=% 4.2f sd=% 4.2f', mnval, sdval_full)});

            subplot(2,2,2); imagesc(mask_holey); axis image;axis off; %colormap(jet);
              title(sprintf('thresh mask nvox=% 5d', sum(mask_holey,'all')));

            subplot(2,2,3); hdmsk=imagesc(log_data,[0,10]); axis image; axis off; colormap(jet);
            title({sprintf('phan (% 5d)=% 4.f', ...
                          mask_nvox, ...
                          sum(DATA(:,:,ll).*mask,'all')/mask_nvox),...
                   sprintf('alias(% 5d)=% 4.2f', ...
                          sum(maskalias,'all'), ...
                          sum(DATA(:,:,ll).*maskalias,'all')/sum(maskalias,'all'))});
              set(hdmsk,'AlphaData',double((maskalias+mask)>0))

            bothmasks = 2*mask_holey+4*mask;
            axmask=subplot(2,2,4); hold off;
            hcmask=imagesc(bothmasks,[2 6]);
            axis image; xticks([]); yticks([]);
            colormap(axmask,hsv(4));
            set(hcmask, 'AlphaData', double(bothmasks>0))
            title(sprintf('circle fit; DX %d DY %d', dx, dy));
            hold on
            visboundaries(mask, 'Color','k', 'LineWidth', .5);
            plot(cx+dx,cy+dy,'g+');%,'MarkerSize',12,'LineWidth',2);
            hold off;
              %suptitle(stitle)
            
            % will fail if -nodisplay (or DISPLAY empty b/c ssh w/o -X or -Y)
            try
                if ll==1, set(vidfig, 'Windowstyle', 'docked'); saveas(gcf,fullfile(outdir,'mask_rois.png'),'png'); end
            end
            % 20261114 - recordvideo
            if ~isempty(vidwrite)
                drawnow;
                writeVideo(vidwrite, getframe(vidfig));
            end
        end % if plot

        mask3d(:,:,ll) = mask;
        maskalias3d(:,:,ll) = maskalias;
    end % for ll
% DX DY 
% mask_size = sum(mask3d,[1 2]);
end % function

