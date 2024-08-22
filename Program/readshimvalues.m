function [shimvalues,shimmode, strbuff] = readshimvalues(fname)
% function [shimvalues,strbuff] = readshimvalues(fname)
%

%disp(fname);

% memory
shimmode = [];
shimvalues = [];

% read in dicom file -- line by line until we run out of character lines
fid = fopen(fname);
strbuff = '';
while ~feof(fid)
    tline = fgetl(fid);
    if ~ischar(tline), break, end
    strbuff = [strbuff newline tline];
end
fclose(fid);
istart = strfind(strbuff,'### ASCCONV BEGIN');
iend = strfind(strbuff,'### ASCCONV END');
% checking
if isempty(strbuff) || isempty(istart) || isempty(iend)
    warning('dicom file header is empty or missing ASCCONV')
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

end

%!test
%! [shimvalues,shimmode, strbuff] = readshimvalues('../example/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/PRISMA3QA.MR.QA_PRISMA3QA.0003.0001.2024.08.09.18.15.49.154822.1380215093.IMA') ;
%! [lOffsetX lOffsetY lOffsetZ sv1 sv2 sv3 sv4 sv5 lFrequency] = num2cell(shimvalues){:};
%! assert(lOffsetX,  2865);
%! assert(lFrequency, 123258356);

% values from:
% example='PRISMA3QA.MR.QA_PRISMA3QA.0003.0001.2024.08.09.18.15.49.154822.1380215093.IMA'
% dicom_hdr -sexinfo $example | grep -P 'lOffsetX|lFreq'
%   sGRADSPEC.asGPAData[0].lOffsetX  =      2865
%   sTXSPEC.asNucleusInfo[0].lFrequency      =      123258356
