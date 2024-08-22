%
% Daily QA w/ Siemens phantom w/ 64ch head-neck coil
% @chm - 08/13/2204
%

% Release memory
clear all;

% Study folder information
pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily';

scanner = {...
    'Prisma1',...
    };
study  = {...
    'QA_PRISMA1QA_20240809_173010_559000',...
    };
series  = {...
    'rfMRI_REST_PA_704x704.3',...
    };
tlabel = {...
    'Coil1Phant1@P1',...
    };

n = length(tlabel);

% call funtion
bfig = 0;
for i=1:n
    tpfolder = [pfolder '/' scanner{1,i} '/' study{1,i} '/' series{1,i}];
    [stat] = dostat(tpfolder,tlabel,bfig);
    
    stat.tlabel = tlabel{1,i};
    stat.dicominfo.StudyDescription;
    stat.dicominfo.StudyDate;
    stat.dicominfo.StationName;
    stat.dicominfo.SequenceName;
    stat.dicominfo.ProtocolName;
    stat.dicominfo.CoilString;
    stat.dicominfo.ImageTypeText;
    
    disp(stat);
end