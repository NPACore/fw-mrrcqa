% https://www.mathworks.com/matlabcentral/answers/780072-slim-installation-of-matlab-runtime
% 2024+ matlab
% https://www.mathworks.com/help/compiler/package-matlab-standalone-applications-into-docker-images.html
% ML images, see 'mathworks/matlab-runtime-deps:r2025b'
% https://github.com/mathworks-ref-arch/container-images

% this format 2021a (does not work with 2019b, nor 2022b)
% https://www.mathworks.com/matlabcentral/answers/780037-matlab-runtime-installer_input-txt#answer_657063

load('requiredMCRProducts.txt') % created by 'mcc' or 
pcmn = matlab.depfun.internal.ProductComponentModuleNavigator;
fid = fopen('installer_input.txt','w');

% if 2022b+ mode=silent
fprintf(fid, 'mode silent\n')
fprintf(fid, 'agreeToLicense yes\n')

fprintf(fid, 'product.MATLAB_Runtime___Core true\n')
for i=requiredMCRProducts
   name = pcmn.productInfo(i).extPName;
   name_ = regexprep(name, '[ -]', '_'),
   fprintf(fid, ['product.' name_ ' true\n'])
   % if 2022b+ ?
   % fprintf(fid, ['product.' name '\n'])
end
