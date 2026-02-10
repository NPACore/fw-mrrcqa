%
% Load phantomqc.csv
% CHM @20240421
% WF @20260210 - add X and Y

%{
0. Mount "moonc@10.48.88.117/barracuda2"
1. Mount "mrtehcs@10.48.88.13/TWIX_RAID"
0. Download "https://rad.pitt.edu/wiki/lib/exe/fetch.php?cache=&media=phantomqc.csv"
1. Save the file in "/Volumes/barracuda2/QADaily/Program"
2. Run 'readcsv.m'
%}

%
clear all;

% 
pfolder = pwd; %'/Volumes/Leopard@barracuda3/QADaily/Program';
fname = 'phantomqc.csv';

strdate = datetime;
strxlim = ['01-Aug-2024' strdate];

%%
P = fullfile(pfolder,fname);
system(['LD_LIBRARY_PATH= curl -k "https://wiki.mrrc.pitt.edu/lib/exe/fetch.php?media=phantomqc.csv" > ', P]);
T = readtable(P); %, 'TreatAsMissing', 'NA');
%T.DATE
%T.scanner
%T.snr
%  DATE         scanner       snr      alias     bkoff      tsnr      Y        Z       X2      Y2     Z2     XY     S2        B0

%         1       2        3      4       5       6    7   8   9    10   11   12   13   14           
%name = {'DATE','scanner','snr','alias','bkoff','tsnr','Y','Z','X2','Y2','Z2','XY','S2','B0'};
%         1       2        3      4       5       6      7      8     9   10  11   12   13   14   15   16  17        
name = {'DATE','scanner','snr','alias','bkoff','tsnr','test','fwhm', 'X', 'Y','Z','X2','Y2','Z2','XY','S2','B0'};
% TODO: use T.Properties.VariableNames instead

%
T.DATE = datetime(T.DATE, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
Tsort = sortrows(T,'scanner');

I1 = contains(Tsort.scanner,'Prisma1');
I2 = contains(Tsort.scanner,'Prisma2');
I3 = contains(Tsort.scanner,'Prisma3');

T1 = Tsort(I1==1,:);
T2 = Tsort(I2==1,:);
T3 = Tsort(I3==1,:);


% Display
%gidx = [3 6 8 14 4 5]; %snr, tsnr, Z, B0, alias, bkoff
% gidx = [3 6 10 16 4 5 8]; %snr, tsnr, Z, B0, alias, bkoff, fwhm
meas_to_plot = {'snr','tsnr', 'X','Y', 'Z', 'B0', 'alias', 'bkoff', 'fwhm'};
gidx = arrayfun(@(col) find(strcmp(col, T.Properties.VariableNames)), ...
                meas_to_plot);
% also see: Temp
legloc = {'southwest','northwest','southwest','northwest','southwest',...
          'southwest','southwest','southwest','southwest','southwest', ...
          'southwest'};
lw = [2 2 2 2 2 2 2 2 2 2 2];
%mode = [0 0 2  2 0 0 0]; %0-abolute; 2-percent
for i=1:length(gidx)
    idx = gidx(i);
    sname = name{idx}; % TODO: should be T.Properties.VariableNames{idx}
    disp(['Plotting ' sname '(' num2str(idx) '); ' T.Properties.VariableNames{idx}]);


    bnumval = 0;
    if contains(class(T1{:,idx}),{'cell'})
        nl = length(T1{:,idx});
        T1val = ones(nl,1);
        for l=1:nl
            strtmp = T1{:,idx}{l}; if contains(strtmp,{'NA' 'na'}), T1val(l) = 0; else T1val(l) = str2num(strtmp);  end
        end
        bnumval = 1;
    end
    if contains(class(T2{:,idx}),{'cell'})
        nl = length(T2{:,idx});
        T2val = ones(nl,1);
        for l=1:nl
            strtmp = T2{:,idx}{l}; if contains(strtmp,{'NA' 'na'}), T2val(l) = 0; else T2val(l) = str2num(strtmp);  end
        end
        bnumval = 1;
    end
    if contains(class(T3{:,idx}),{'cell'})
        nl = length(T3{:,idx});
        T3val = ones(nl,1);
        for l=1:nl
            strtmp = T3{:,idx}{l}; if contains(strtmp,{'NA' 'na'}), T3val(l) = 0; else T3val(l) = str2num(strtmp);  end
        end
        bnumval = 1;
    end

    if mode(i)==0
        disp('# ploting abs vals')
        if bnumval==0
            figure(1); subplot(length(gidx)+1,1,i); plot(T1{:,1},T1{:,idx},'r-',T2{:,1},T2{:,idx},'b-',T3{:,1},T3{:,idx},'g-','LineWidth',lw(i)); 
        else
            figure(1); subplot(length(gidx)+1,1,i); plot(T1{:,1},T1val,'r-',T2{:,1},T2val,'b-',T3{:,1},T3val,'g-','LineWidth',lw(i)); 
        end

        legend({'Prisma1','Prisma2','Prisma3'},'Location',legloc{i},'NumColumns',1); axis tight; ylabel(upper(sname),'FontSize',20); grid on;
        xlim(strxlim);
    elseif mode(i)==1
        disp('# ploting rel vals')
        figure(1); subplot(length(gidx)+1,1,i); plot(T1{:,1},T1{:,idx}-mean(T1{:,idx}),'r-',T2{:,1},T2{:,idx}-mean(T2{:,idx}),'b-',T3{:,1},T3{:,idx}-mean(T3{:,idx}),'g-','LineWidth',lw(i)); 
        legend({'Prisma1','Prisma2','Prisma3'},'Location',legloc{i},'NumColumns',1); axis tight; ylabel([upper(sname) ' - mean(' upper(sname) ')'],'FontSize',20); grid on;
        xlim(strxlim);
    else
        disp(['# ploting neither abs nor rel vals; ', mode(i)])
        figure(1); subplot(length(gidx)+1,1,i); 
        prct = @(x) (x-nanmean(x))/nanmean(x)*100;
        T1val = prct(na0(T1{:,idx})); T2val = prct(na0(T2{:,idx})); T3val = prct(na0(T3{:,idx}));
        plot(T1{:,1},T1val,'r-',...
             T2{:,1},T2val,'b-',...
             T3{:,1},T3val,'g-',...
             'LineWidth',lw(i)); 
        if i < 2 % 20260210 don't need line legend on every plot?
            legend({'Prisma1','Prisma2','Prisma3'},...
                'Location',legloc{i},...
                'NumColumns',1);
        end
        axis tight;
        ylabel([upper(sname) '(%)'],'FontSize',20);
        grid on;
        xlim(strxlim);
    end
end

%set(gcf, 'Windowstyle', 'docked'); saveas(gcf,['DailyQA' date '.png'],'png'); 

%% tempurature log
% previously pulled separeatly. now using what's aggregated in QC csv

%P = '/Volumes/TWIX_RAID/temp log.xlsx';
%if ~ exist(P,'file'),
%   if exist('./00_get_temp.bash','file'), system('./00_get_temp.bash'); end % makes temp tempurature_log.xlsx
%   P = 'tempurature_log.xlsx';
%   if ~ exist(P,'file'), error('No tempurature'); end
%end
%Tdeg = readtable(P);
%%          1       2         3         4       5        6
%name = {'DATE','PRISMA1','PRISMA2','PRISMA3','Var5','Comments'};
%
legloc = {'southwest','northwest','southwest','northwest'};
sname = 'Temperature(F)';
figure(1); subplot(length(gidx)+1,1,i+1);
% was
%  plot(Tdeg{:,1},Tdeg{:,2},'r-x',Tdeg{:,1},Tdeg{:,3},'b-o',Tdeg{:,1},Tdeg{:,4},'g-s','LineWidth',2);
for scanner = {{'Prisma1','r-x'},  {'Prisma2','b-o'},  {'Prisma3','g-s'}},
   scanner = scanner{1};
   % rows that are the current scanner AND valid value (not Temp=='NA')
   s_idx = strcmp(scanner{1},T.scanner) & ~strcmp('NA',T.Temp);
   temp = str2num(cell2mat(T.Temp(s_idx))); % undo 'NA' made all values a string, stored as cell
   plot(T.DATE(s_idx), temp, scanner{2}); hold on
end

legend({'Prisma1','Prisma2','Prisma3'},'Location',legloc{1},'NumColumns',1); axis tight; ylabel(upper(sname),'FontSize',20); grid on;
xlim(['01-Aug-2024',max(T.DATE)]);


%%
fprintf(2,'\nLatest scan date - %s\n', T1{end,1});
figure(1); subplot(length(gidx)+1,1,1); title(sprintf('Latest scan date - %s', T1{end,1}),'FontSize',30);

%%
% set(gcf, 'Windowstyle', 'docked'); %saveas(gcf,['DailyQA' date '.png'],'png');
%exportgraphics(gcf,['DailyQA' date '.png'],'Resolution',300);
%set(gcf, 'Windowstyle', 'docked'); %saveas(gcf,[pfolder filesep 'DailyQA' date '.png'],'png'); 
%exportgraphics(gcf,[pfolder filesep 'DailyQA' date '.png'],'Resolution',300);

%% export w/R2019a
fig_fname = [pfolder filesep 'DailyQA.png'];
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 8 11])
print(gcf,fig_fname,"-dpng", '-r300')



