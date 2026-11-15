function  [b1vals] = readB1values(strbuff)
% READB1VALUES - extract B1 'aTxScaleFactor' from ASCCONV string buffer
% returns struct with names dRe_0 to dIm_7
% see readshimvalues() for strbuff extraction from dicom info

    %% regular expression extracting
    [tokens,matches] = regexp(strsplit(strbuff,'\n'),...
                              'sTXSPEC.aTxScaleFactor\[(\d+)\]\.(dRe|dIm).*=\s*([-0-9.]+)',...
                              'tokens','match');
    match_i = ~cellfun(@isempty, tokens);
    num_chn_val =tokens(match_i);
    %b1vals = cellfun(@(x) str2num(x{1}{3}), num_chn_val);

    %% explict name
    % could return using above.
    % that would give values in order as they appear in ASCCONV 
    % BUT we eventually saving to json, so we can give each value a name
    % then order (or missingnesss) doesn't cause an error

    %names = cellfun(@(x) [x{1}{2} '_' x{1}{1}], num_chn_val, 'Uni',0);
    %sprintf('%s\n%s',strjoin(names, '    '), sprintf('% 2.04f  ',b1vals))

    %dRe_0  dRe_1   dIm_1  dRe_2   dIm_2    dRe_3   dIm_3    dRe_4   dIm_4   dRe_5  dIm_5  dRe_6   dIm_6   dRe_7   dIm_7
    %0.4628 0.3723 -0.3058 0.2944  -0.1291  0.0392  -0.0605 -0.3174  0.1847 -0.1635 0.3683 0.0051  0.4407  0.3163  0.3334  '

    b1vals=struct();
    for ncv = num_chn_val
        ncv=ncv{1}{1};
        n=[ncv{2} '_' ncv{1}];
        b1vals.(n) = str2num(ncv{3});
    end
end

%{
  B1 shim values
  sTXSPEC.aTxScaleFactor[0].dRe    =      0.462790732647
  sTXSPEC.aTxScaleFactor[1].dRe    =      0.37228162203
  sTXSPEC.aTxScaleFactor[1].dIm    =      -0.305833690266
  sTXSPEC.aTxScaleFactor[2].dRe    =      0.294367013437
  sTXSPEC.aTxScaleFactor[2].dIm    =      -0.129144133686
  sTXSPEC.aTxScaleFactor[3].dRe    =      0.0392477685082
  sTXSPEC.aTxScaleFactor[3].dIm    =      -0.0605355047649
  sTXSPEC.aTxScaleFactor[4].dRe    =      -0.317435440855
  sTXSPEC.aTxScaleFactor[4].dIm    =      0.184730219892
  sTXSPEC.aTxScaleFactor[5].dRe    =      -0.163460842706
  sTXSPEC.aTxScaleFactor[5].dIm    =      0.368348483789
  sTXSPEC.aTxScaleFactor[6].dRe    =      0.00511283003483
  sTXSPEC.aTxScaleFactor[6].dIm    =      0.440694915473
  sTXSPEC.aTxScaleFactor[7].dRe    =      0.316280757398
  sTXSPEC.aTxScaleFactor[7].dIm    =      0.33335152552
%}
