function [shimXYZ_uT_m] = calc_gradients(shimvalues, GradSensitivity, verbose)
% CALC_GRADIENTS - uT/m from dicom shimvalues and GradSensitivity (DAC*uT/m/DAC)
%  see readshimvalues.m for shimvalues and GradSensitivity
%  e.g. sGRADSPEC.asGPAData[0].lOffsetX, sTXSPEC.asNucleusInfo[0].lFrequency, sGRADSPEC.asGPAData[0].flSensitivityX
shimXYZ_uT_m = shimvalues(1:3).*GradSensitivity(1:3);

% default to showing all measures
if nargin < 3, verbose=1; end

%% display
if verbose
  disp(['shim(calc)         :   X,   Y,   Z = ' num2str(shimXYZ_uT_m)    ' (uT/m)' ]);
  disp(['GPAData(raw sens)  : GSX, GSY, GSZ = ' num2str(GradSensitivity) ' (uT/m/DAC)' ]);
  disp(['GPAData(raw offset):   X,   Y,   Z = ' num2str(shimvalues(1:3)) ' (DAC)' ]);
  
  % not returned already in shimvalues extracted from dicom
  shim2nd_uT_m2 = shimvalues(4:end-1);
  disp(['GPAData(raw offest):  X2,  Y2,  Z2 = ' num2str(shim2nd_uT_m2(1:3)) ' (uT/m^2)' ]);
  disp(['GPAData(raw offest):     S2,  C2   = ' num2str(shim2nd_uT_m2(4:5)) ' (uT/m^2)' ]);
end

end

%!test
%! [shimvalues,shimmode, strbuff, gs] = readshimvalues('../input/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/PRISMA3QA.MR.QA_PRISMA3QA.0003.0001.2024.08.09.18.15.49.154822.1380215093.IMA') ;
%! XYZ = calc_gradients(shimvalues, gs, 0);
%! assert(XYZ,[0.45792595905393 -1.776375690398995 1.919073480530184], 10e-10);

%!testif ; exist('../input/Prisma1QA20251110_ep2d_bold_p2_s2_5min/1.3.12.2.1107.5.2.43.67078.2025111006283099611901233.MR.dcm')==2
%! [shimvalues,shimmode, strbuff, gs] = readshimvalues('../input/Prisma1QA20251110_ep2d_bold_p2_s2_5min/1.3.12.2.1107.5.2.43.67078.2025111006283099611901233.MR.dcm') ;
%! XYZ = calc_gradients(shimvalues, gs, 0);
%! assert(XYZ,[-0.20563     0.66392      1.6341], 10e-5);
