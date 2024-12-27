%
% Read spreadsheet excel 
% @chm - 2024/10/14
%

%
clear all;
close all;

%
baseFileName = 'DailyQA.xlsx';     

%
tblAllSheetData1 = [];
tblAllSheetData3 = [];
tblAllSheetData3 = [];

%
sheetNames = sheetnames(baseFileName);
for k=1:numel(sheetNames)
	thisTable = readtable(baseFileName,'Sheet',sheetNames{k});
	fprintf('Read a table of %d rows and %d columns from a sheet names %s.\n',...
		height(thisTable), width(thisTable), sheetNames{k});

    switch sheetNames{k}
        case {'Prisma1', 'PRISMA1'}
            tblAllSheetData1 = thisTable;
        case {'Prisma2', 'PRISMA2'}
            tblAllSheetData2 = thisTable;
        case {'Prisma3', 'PRISMA3'}
            tblAllSheetData3 = thisTable;
        otherwise
            disp('Scanner name is wrong!!');
    end
end

%
structAllSheetData1 = table2struct(tblAllSheetData1);
structAllSheetData2 = table2struct(tblAllSheetData2);
structAllSheetData3 = table2struct(tblAllSheetData3);

%
mSNR=[]; sSNR=[];
mtSNR=[]; stSNR=[];
mALIAS=[]; sALIAS=[];
mBGOff=[]; sBGOff=[];
mX=[]; sX=[];
mY=[]; sY=[];
mZ=[]; sZ=[];
mX2=[]; sX2=[];
mY2=[]; sY2=[];
mZ2=[]; sZ2=[];
mXY=[]; sXY=[];
mS2=[]; sS2=[];
mB0=[]; sB0=[];

for i=1:3
    switch i
        case 1
            structdata = structAllSheetData1;
        case 2
            structdata = structAllSheetData2;
        case 3
            structdata = structAllSheetData3;
        otherwise
            ;
    end

    DATE = vertcat(structdata(:,1).DATE);
    SNR = vertcat(structdata(:,1).SNR);
    ALIAS = vertcat(structdata(:,1).ALIAS);
    BGOff = vertcat(structdata(:,1).BGOff);
    tSNR = vertcat(structdata(:,1).tSNR);
    X = vertcat(structdata(:,1).X);
    Y = vertcat(structdata(:,1).Y);
    Z = vertcat(structdata(:,1).Z);
    X2 = vertcat(structdata(:,1).X2);
    Y2 = vertcat(structdata(:,1).Y2);
    Z2 = vertcat(structdata(:,1).Z2);
    XY = vertcat(structdata(:,1).XY);
    S2 = vertcat(structdata(:,1).S2);
    B0 = vertcat(structdata(:,1).B0);

    %
    mSNR = [mSNR mean(SNR)]; sSNR = [sSNR std(SNR)];
    mtSNR = [mtSNR mean(tSNR)]; stSNR = [stSNR std(tSNR)];
    mALIAS = [mALIAS mean(ALIAS)]; sALIAS = [sALIAS std(ALIAS)];
    mBGOff = [mBGOff mean(BGOff)]; sBGOff = [sBGOff std(BGOff)];

    mX = [mX mean(X)]; sX = [sX std(X)];
    mY = [mY mean(Y)]; sY = [sY std(Y)];
    mZ = [mZ mean(Z)]; sZ = [sZ std(Z)];
    
    mX2 = [mX2 mean(X2)]; sX2 = [sX2 std(X2)];
    mY2 = [mY2 mean(Y2)]; sY2 = [sY2 std(Y2)];
    mZ2 = [mZ2 mean(Z2)]; sZ2 = [sZ2 std(Z2)];
    mXY = [mXY mean(XY)]; sXY = [sXY std(XY)];
    mS2 = [mS2 mean(S2)]; sS2 = [sS2 std(S2)];

    mB0 = [mB0 mean(B0)]; sB0 = [sB0 std(B0)];
    b0time = [];
    for t=1:length(B0)
        b0 = std(B0(1:t));
        b0time = [b0time b0];
    end
    switch i
        case 1
            b0time1 = b0time;
            DD1 = DATE;
        case 2
            b0time2 = b0time;
            DD2 = DATE;
        case 3
            b0time3 = b0time;
            DD3 = DATE;
        otherwise
            ;
    end
        
    %
    figure(1); subplot(4,3,(i-1)+1,'replace'); bar(SNR,'r'); xticklabels(DATE); axis([1 length(SNR) 150 240]); ylabel('SNR'); title(['Prisma' num2str(i)]);
    figure(1); subplot(4,3,(i-1)+4,'replace'); bar(tSNR,'m'); xticklabels(DATE); axis([1 length(tSNR) 0 80]); ylabel('tSNR');
    figure(1); subplot(4,3,(i-1)+7,'replace'); bar(ALIAS,'b'); xticklabels(DATE);  ylabel('Alias'); axis([1 length(ALIAS) 0 15]);
    figure(1); subplot(4,3,(i-1)+10,'replace'); bar(BGOff,'k'); xticklabels(DATE);  ylabel('BGoff'); axis([1 length(BGOff) 0 50]);

    figure(2); subplot(10,3,(i-1)+1,'replace'); bar(X,'k'); xticklabels(DATE);  ylabel('X');  title(['Prisma' num2str(i)]); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+4,'replace'); bar(Y,'k'); xticklabels(DATE);  ylabel('Y'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+7,'replace'); bar(Z,'k'); xticklabels(DATE);  ylabel('Z'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+10,'replace'); bar(X2,'k'); xticklabels(DATE);  ylabel('X2'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+13,'replace'); bar(Y2,'k'); xticklabels(DATE);  ylabel('Y2'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+16,'replace'); bar(Z2,'k'); xticklabels(DATE);  ylabel('Z2'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+19,'replace'); bar(XY,'k'); xticklabels(DATE);  ylabel('XY'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+22,'replace'); bar(S2,'k'); xticklabels(DATE);  ylabel('S2'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+25,'replace'); bar(B0,'k'); xticklabels(DATE);  ylabel('B0'); %axis([1 length(BGOff) 0 30]);
    figure(2); subplot(10,3,(i-1)+28,'replace'); bar(B0-B0(2),'r'); xticklabels(DATE);  ylabel('dB0, Hz'); ylim([-50 100]);  %axis([1 length(BGOff) 0 30]);
end

%
figure(1); set(gcf,'Name','SNR, tSNR, ALIAS, BGOFF'); drawnow;
set(gcf, 'Windowstyle', 'docked'); saveas(gcf,['SNRtSNR.png'],'png'); 
figure(2); set(gcf,'Name','B0 shims'); drawnow;
set(gcf, 'Windowstyle', 'docked'); saveas(gcf,['ShimB0.png'],'png'); 

%
x= [1:3];
strxaxis = {'Prisma1', 'Prisma2', 'Prisma3'};
figure(10); subplot(4,4,1); bar(strxaxis,mSNR,'k'); ylabel('SNR'); hold on; er = errorbar(x,mSNR,sSNR,sSNR); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,2); bar(strxaxis,mtSNR,'k'); ylabel('tSNR'); hold on; er = errorbar(x,mtSNR,stSNR,stSNR); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,3); bar(strxaxis,mALIAS,'k'); ylabel('ALIAS'); hold on; er = errorbar(x,mALIAS,sALIAS,sALIAS); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,4); bar(strxaxis,mBGOff,'k'); ylabel('BGOff'); hold on; er = errorbar(x,mBGOff,sBGOff,sBGOff); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,5); bar(strxaxis,mX,'k'); ylabel('X'); hold on; er = errorbar(x,mX,sX,sX); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,6); bar(strxaxis,mY,'k'); ylabel('Y'); hold on; er = errorbar(x,mY,sY,sY); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,7); bar(strxaxis,mZ,'k'); ylabel('Z'); hold on; er = errorbar(x,mZ,sZ,sZ); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,8); bar(strxaxis,mX2,'k'); ylabel('X2'); hold on; er = errorbar(x,mX2,sX2,sX2); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,9); bar(strxaxis,mY2,'k'); ylabel('Y2'); hold on; er = errorbar(x,mY2,sY2,sY2); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,10); bar(strxaxis,mZ2,'k'); ylabel('Z2'); hold on; er = errorbar(x,mZ2,sZ2,sZ2); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,11); bar(strxaxis,mXY,'k'); ylabel('XY'); hold on; er = errorbar(x,mXY,sXY,sXY); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,12); bar(strxaxis,mS2,'k'); ylabel('S2'); hold on; er = errorbar(x,mS2,sS2,sS2); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off
figure(10); subplot(4,4,13); bar(strxaxis,mB0,'k'); ylabel('B0'); hold on; er = errorbar(x,mB0,sB0,sB0); er.Color = [0 0 0]; er.LineStyle = 'none';  hold off

figure(10); subplot(4,4,14); bar(b0time1,'r'); xticklabels(DD1);  ylabel('dB0'); title('Prisma1');
figure(10); subplot(4,4,15); bar(b0time2,'r'); xticklabels(DD2);  ylabel('dB0'); title('Prisma2');
figure(10); subplot(4,4,16); bar(b0time3,'r'); xticklabels(DD3);  ylabel('dB0'); title('Prisma3');


figure(10); set(gcf,'Name','Statistics of Scanners'); drawnow;
set(gcf, 'Windowstyle', 'docked'); saveas(gcf,['Statistics.png'],'png'); 


figure(11); subplot(2,2,1,'replace'); plot(x,sSNR./mSNR*100,'r-O',x,stSNR./mtSNR*100,'b-X','LineWidth',2,'MarkerSize',10); xticks([1 2 3]); xticklabels(strxaxis); ylabel('VarSNR[%]'); 
legend('SNR','tSNR'); grid on;
figure(11); subplot(2,2,2,'replace'); plot(x,sB0,'r-O','LineWidth',2,'MarkerSize',10); xticks([1 2 3]); xticklabels(strxaxis); ylabel('dB0[Hz]'); 
legend('B0'); grid on;
figure(11); subplot(2,2,3,'replace'); plot(x,sX./mX*100,'r-O',x,sY./mY*100,'b-X',x,sZ./mZ*100,'g-s','LineWidth',2,'MarkerSize',10); xticks([1 2 3]); xticklabels(strxaxis); ylabel('X/Y/Z[%]'); 
legend('X','Y','Z'); grid on;
figure(11); subplot(2,2,4,'replace'); plot(x,sX2./mX2*100,'r-O',x,sY2./mY2*100,'b-X',x,sZ2./mZ2*100,'g-s',x,sXY./mXY*100,'k-d',x,sS2./mS2*100,'m-^','LineWidth',2,'MarkerSize',10); xticks([1 2 3]); xticklabels(strxaxis); ylabel('X2/Y2/Z2[%]'); 
legend('X2','Y2','Z2','XY','S2'); grid on;
figure(11); set(gcf,'Name','Variation, std/mean'); drawnow;
set(gcf, 'Windowstyle', 'docked'); saveas(gcf,['Var_std_vs_mean.png'],'png'); 
