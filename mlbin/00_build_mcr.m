results = compiler.build.standaloneApplication("../Program/dostats.m");
% compiler.runtime.download
% MATLAB Runtime installer has been downloaded to:
% "/home/foranw/MCRInstaller9.10/MATLAB_Runtime_R2021a_Update_4_glnxa64.zip"
compiler.runtime.customInstaller("qastat", results)                  
