function [shimvalues,shimmode, strbuff] = readshimvalues(fname)
% function [shimvalues,strbuff] = readshimvalues(fname)
%

%disp(fname);

% memory
shimmode = [];
shimvalues = [];

% readind dicom file
fid = fopen(fname);
strbuff = [];
tline = fgetl(fid); 
strbuff = [strbuff newline tline];
while ischar(tline)
    tline = fgetl(fid);
    strbuff = [strbuff newline tline];
end
fclose(fid);
istart = strfind(strbuff,'### ASCCONV BEGIN');
iend = strfind(strbuff,'### ASCCONV END');
% checking
if isempty(strbuff)
    istart
    iend
    return;
end
if isempty(istart)
    istart
    iend
    return;
end
if isempty(iend)
    istart
    iend
    return;
end
%strbuff = strbuff(istart:iend);
strbuff = strbuff(istart(1):iend(end));

% shimMode
% sAdjData.uiAdjShimMode	 = 	4
idxs = strfind(strbuff,'sAdjData.uiAdjShimMode');
if ~isempty(idxs)
    strtmp = strbuff(idxs:end);
    idxe = strfind(strtmp, newline);
    %strucMode = strtmp(1:idxe-1);
    strucMode = strtmp(1:idxe(1)-1);
    idx = strfind(strucMode,'=');
    %@chm - 11/16/2022
    strtmp = strtrim(strucMode(idx+1:end));
    strtmp = erase(strtmp,'0x');
    ucMode = str2num(strtmp);
else
    ucMode = 0;
end

% shimvalues
% sGRADSPEC.asGPAData[0].lOffsetY	 = 	-2520
idxs = strfind(strbuff,'sGRADSPEC.asGPAData[0].lOffsetX');
if ~isempty(idxs)
    strtmp = strbuff(idxs:end);
    idxe = strfind(strtmp, newline);
    %strlOffsetX = strtmp(1:idxe-1);
    strlOffsetX = strtmp(1:idxe(1)-1);
    idx = strfind(strlOffsetX,'=');
    lOffsetX = str2num(strtrim(strlOffsetX(idx+1:end)));
else
    lOffsetX = 0;
end

idxs = strfind(strbuff,'sGRADSPEC.asGPAData[0].lOffsetY');
if ~isempty(idxs)
    strtmp = strbuff(idxs:end);
    idxe = strfind(strtmp, newline);
    %strlOffsetX = strtmp(1:idxe-1);
    strlOffsetX = strtmp(1:idxe(1)-1);
    idx = strfind(strlOffsetX,'=');
    lOffsetY = str2num(strtrim(strlOffsetX(idx+1:end)));
else
    lOffsetY = 0;
end

idxs = strfind(strbuff,'sGRADSPEC.asGPAData[0].lOffsetZ');
if ~isempty(idxs)
    strtmp = strbuff(idxs:end);
    idxe = strfind(strtmp, newline);
    %strlOffsetX = strtmp(1:idxe-1);
    strlOffsetX = strtmp(1:idxe(1)-1);
    idx = strfind(strlOffsetX,'=');
    lOffsetZ = str2num(strtrim(strlOffsetX(idx+1:end)));
else
    lOffsetZ = 0;
end

alShimCurrent = zeros(1,5);
for i=1:5
    strtt = sprintf('sGRADSPEC.alShimCurrent[%d]',i-1);
    idxs = strfind(strbuff,strtt);
    if ~isempty(idxs)
        strtmp = strbuff(idxs:end);
        idxe = strfind(strtmp, newline);
        %strlOffsetX = strtmp(1:idxe-1);
        strlOffsetX = strtmp(1:idxe(1)-1);
        idx = strfind(strlOffsetX,'=');
        alShimCurrent(i) = str2num(strtrim(strlOffsetX(idx+1:end)));
    else
        alShimCurrent(i) = 0;
    end
end

idxs = strfind(strbuff,'sTXSPEC.asNucleusInfo[0].lFrequency');
if ~isempty(idxs)
    strtmp = strbuff(idxs:end);
    idxe = strfind(strtmp, newline);
    %strlOffsetX = strtmp(1:idxe-1);
    strlOffsetX = strtmp(1:idxe(1)-1);
    idx = strfind(strlOffsetX,'=');
    lFrequency = str2num(strtrim(strlOffsetX(idx+1:end)));
else
    lFrequency = 0;
end

%
shimvalues = [lOffsetX lOffsetY lOffsetZ];
for i=1:5
    shimvalues = [shimvalues alShimCurrent(i)];
end
shimvalues = [shimvalues lFrequency];

shimmode = ucMode;

return;
