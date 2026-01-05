results = compiler.build.standaloneApplication("../Program/dostat.m");

% 20251231, on ML 2024a on oacnucleus.
% compiler.runtime.createDockerImage(results) 
compiler.package.docker(results, 'ImageName', 'fwmrrcqa')
system('docker image   ls --format=json fwmrrcqa|jq -r .Size') % 3.57GB


compiler.runtime.download % will not redownload if existing
% MATLAB Runtime installer has been downloaded to:
% "/home/foranw/MCRInstaller9.10/MATLAB_Runtime_R2021a_Update_4_glnxa64.zip"
% "/home/foranw/MCRInstaller24.1/MATLAB_Runtime_R2024a_Update_6_glnxa64.zip"

error('below not tested')

% TODO: how large? is below more space efficent?
% https://www.mathworks.com/help/compiler/compiler.runtime.custominstaller.html
% version, % '24.1.0.2689473 (R2024a) Update 6'
compiler.runtime.customInstaller("qastat", results)                  
% > Unable to resolve the name 'compiler.runtime.customInstaller'.

% also see
% https://www.mathworks.com/help/compiler/compiler.runtime.createdockerimage.html
compiler.runtime.createDockerImage(...
    ["add/requiredMCRProducts.txt",...
     "eig/requiredMCRProducts.txt"],
    'ImageName','fw-mrrc:mlbin',...
    'DockerContext','runtime')
