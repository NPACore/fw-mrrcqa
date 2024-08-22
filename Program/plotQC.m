function plotQC(stat, tlabel, f)
  if nargin < 3, f=figure(1); else figure(f); end
  if nargin < 2, tlabel = ''; end

  reportstat = [stat.snrpk stat.aliaspk stat.bkoffpk stat.tsnrpk stat.shim(1:end-1) stat.shim(end)/1000];
  
  
  subplot(3,1,1);
    bar(1:4,reportstat(1:4));
    set(gca, 'XTickLabel', {'SNR','ALIAS','BGOff','tSNR'});
    if tlabel, legend(tlabel), end
  subplot(3,1,2);
     bar(reportstat(5:end-1))
     set(gca, 'XTickLabel', {'X','Y','Z','X2','Y2','Z2','XY','S2'});
     if tlabel, legend(tlabel), end
  subplot(3,1,3);
      bar(reportstat(end:end));
      legend('B0');
end
