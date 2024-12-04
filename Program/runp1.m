%% Daily QA w/ Siemens phantom w/ 64ch head-neck coil
% @chm - 08/13/2204
%

% Release memory
clear all;
close all;


% Study folder information
pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily';

% scanner
for iscanner=1:3 %1:3

    if iscanner == 1
        scanner = 'Prisma1';
        study = 'Prisma1QA';
        study1 = 'PRISMA1QA';
        series = 'ep2d_bold_p2_s2_5min';
        tlabel = 'Coil1Phant1@P1';
        exclusions = {};
    elseif iscanner ==2
        scanner = 'Prisma2';
        study = 'Prisma2QA';
        study1 = 'PRISMA2QA';
        series = 'ep2d_bold_p2_s2_5min';
        tlabel = 'Coil2Phant2@P2';
        exclusions = {}; %{'Prisma2QA20241008', 'Prisma2QA20241018', 'Prisma2QA20241024', 'Prisma2QA20241026'}; %something wrong scan!
    elseif iscanner == 3
        scanner = 'Prisma3';
        study = 'Prisma3QA';
        study1 = 'PRISMA3QA';
        series = 'ep2d_bold_p2_s2_5min';
        tlabel = 'Coil3Phant3@P3';
        exclusions = {'Prisma3QA20241104'};
    else
        return;
    end
    
    % scan date
    %scandate = [20240101 20241231];
    scandate = [20240801 20241231];
    bfig = 1;
    
    % 2
    P = [pfolder '/' scanner];
    D = dir([P '/' study '*']);
    P1 = [pfolder '/' scanner];
    D1 = dir([P1 '/' study1 '*']);
    ndates = length(D); % + length(D1); % MATLAB no differentiation of small and CAPITAL folder in dir()
    
    % scan dates
    reportstatgrp = [];
    
    tlabel = cell(1,ndates);
    reportstatgrpstruct = [];
    
    cnt = 0;
    for i=1:ndates
        if i <= length(D)
            name = D(i,1).name;
            folder = D(i,1).folder;
        else
            name = D1(i-length(D),1).name;
            folder = D1(i-length(D),1).folder;
        end
        fullfolder = [folder '/' name];
        if ~isfolder(fullfolder), 
            continue; 
        else
            % checking date range
            datastr = replace(name,study,'');
            datenum = str2num(datastr);
            if datenum < scandate(1), continue; end
            if datenum > scandate(2), continue; end
    
            cnt = cnt+1;
        end
    
        % mat or dicom
        matfile = [pfolder '/Program/' name '.mat'];
    
        if contains(name, exclusions)
            cnt = cnt - 1;
            continue;
        end
    
        TF = isfile(matfile);
        if TF==1,
            disp(matfile);
            load(matfile);
        else
            episcan = [fullfolder '/' series];
            if ~isfolder(episcan), continue; end
            disp(episcan)
            [stat] = dostat(episcan,[],bfig);
        end
    
        reportstatgrpstruct(cnt).date = datenum;
        tlabel{1,cnt} = name;
    
        % save
        stat.tlabel = tlabel{1,i};
        stat.dicominfo.StudyDescription;
        stat.dicominfo.StudyDate;
        stat.dicominfo.StationName;
        stat.dicominfo.SequenceName;
        stat.dicominfo.ProtocolName;
        stat.dicominfo.CoilString;
        stat.dicominfo.ImageTypeText; 
        %disp(stat);
    
        %reportstat = [int64(datenum) stat.snrpk stat.aliaspk stat.bkoffpk stat.tsnrpk stat.shim(1:end-1) int64(stat.shim(end))];
        reportstat = [double(datenum) stat.snrpk stat.aliaspk stat.bkoffpk stat.tsnrpk stat.shim(1:end-1) double(stat.shim(end))];
        %disp(reportstat);
    
        reportstatgrp = [reportstatgrp; reportstat];
    
        %{
        reportstatgrpstruct(cnt).SNR = stat.snrpk;
        reportstatgrpstruct(cnt).ALIAS = stat.aliaspk;
        reportstatgrpstruct(cnt).BGOff = stat.bkoffpk;
        reportstatgrpstruct(cnt).tSNR = stat.tsnrpk;
        reportstatgrpstruct(cnt).X = stat.shim(1);
        reportstatgrpstruct(cnt).Y = stat.shim(2);
        reportstatgrpstruct(cnt).Z = stat.shim(3);
        reportstatgrpstruct(cnt).X2 = stat.shim(4);
        reportstatgrpstruct(cnt).Y2 = stat.shim(5);
        reportstatgrpstruct(cnt).Z2 = stat.shim(6);
        reportstatgrpstruct(cnt).XY = stat.shim(7);
        reportstatgrpstruct(cnt).S2 = stat.shim(8);
        reportstatgrpstruct(cnt).B0 = stat.shim(end)/1000;
        %}
    
        % SNR distribution
        H=figure(20); 
        if i==1, 
            p=subplot(1,1,1,'replace'); 
        else
            p=subplot(1,1,1); 
        end
        p.YLabel.String='#count'; p.XLabel.String='SNR'; hold on; 
        plot(stat.snr(2,:),stat.snr(1,:),'LineWidth',2); set(H,'Name', pfolder); axis([150 400 0 400]); legend(tlabel(1:cnt),'FontSize',10); drawnow;
        hold off;
    
        % save
        if TF~=1
            save(matfile, 'stat');
        end
       
    end
    
    tlabel = tlabel(1,1:cnt);
    
    txlabel = {'DATE', 'SNR','ALIAS','BGOff','tSNR','X','Y','Z','X2','Y2','Z2','XY','S2','B0'};
    figure(1); subplot(3,1,1); bar(txlabel(2:5),reportstatgrp(:,2:5)'); legend(tlabel);
    %txlabel1 = {'X','Y','Z','X2','Y2','Z2','XY','S2'};
    figure(1); subplot(3,1,2); bar(txlabel(6:end-1),reportstatgrp(:,6:end-1)'); legend(tlabel);
    figure(1); subplot(3,1,3); bar(reportstatgrp(:,end:end)'); legend('B0');
    
    figure(10); subplot(2,2,1); bar(tlabel,reportstatgrp(:,2)); ylabel('SNR'); 
    figure(10); subplot(2,2,2); bar(tlabel,reportstatgrp(:,3)); ylabel('ALIAS'); 
    figure(10); subplot(2,2,3); bar(tlabel,reportstatgrp(:,4)); ylabel('BACK GRAOUND'); 
    figure(10); subplot(2,2,4); bar(tlabel,reportstatgrp(:,5)); ylabel('tSNR'); 
    
    % table
    tableLine = array2table(reportstatgrp,'VariableNames',txlabel); %table labeling in MATLAB
    %tableLine = array2table(reportstatgrpstruct); %table labeling in MATLAB
    
    stLine = table2struct(tableLine);
    for i=1:length(stLine)
        dd = num2str(stLine(i,1).DATE);
        stLine(i,1).DATE = [dd(1:4) '-' dd(5:6) '-' dd(7:8)];
    end
    tableLine = struct2table(stLine);
    
    rangestr = ['A' '1'];
    writetable(tableLine,'DailyQA.xlsx','Sheet',scanner,'Range',rangestr,'WriteRowNames',true,'WriteVariableNames', true);
    
    % Summary
    fp = fopen('DailySNRtSNR.txt', 'a');
    strdate = date;
    fprintf(fp,'\n@%s\n', strdate);
    snrvar = std(reportstatgrp(:,2))/mean(reportstatgrp(:,2))*100;
    tsnrvar = std(reportstatgrp(:,5))/mean(reportstatgrp(:,5))*100;
    B0 = reportstatgrp(:,end:end)';
    mB0 = mean(B0);
    sB0 = std(B0);
    fprintf('\n%s: SNR/tSNR/SNRVar/tSNRVar/B0/dB0 = %3.2f/%3.2f[DL]\t\t%3.2f/%3.2f[%%]\t\t%3.2f/%3.2f[Hz]\n', ...
        scanner, mean(reportstatgrp(:,2)), mean(reportstatgrp(:,5)), snrvar, tsnrvar, mB0, sB0);
    
    fprintf(fp,'%s: SNR/tSNR/SNRVar/tSNRVar/B0/dB0 = %3.2f/%3.2f[DL]\t\t%3.2f/%3.2f[%%]\t\t%3.2f/%3.2f[Hz]', ...
        scanner, mean(reportstatgrp(:,2)), mean(reportstatgrp(:,5)), snrvar, tsnrvar, mB0, sB0);
    
    fclose(fp);
    
    % 
    %readexcel;
    
    %
    figure(20); set(gcf,'Name','Hoistogram'); drawnow;
    set(gcf, 'Windowstyle', 'docked'); saveas(gcf,[scanner 'Hist.png'],'png'); 


end %for iscanner=1:3
