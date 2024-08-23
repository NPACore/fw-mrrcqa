%
%


%save(matfname, 'phansignal','totnoisesignal','aliasnoisesignal','noisesignal','ro_noisesignal','pe_noisesignal');

%%
isel = 1;

if isel==1
    %@P1
    figoff = 0;
    %@P1; P1 coil and P1 phantom
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma1/QA_PRISMA1QA_20240809_173010_559000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat = load(matfname);
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma1/QA_PRISMA1QA_20240809_173010_559000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat_coil = load(matfname);

elseif isel==2
    %@P2
    figoff = 1;
    %@P2; P1 coil and phantom
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma2/QA_PRISMA2QA_20240809_174910_732000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat = load(matfname);
    %@P2; P2 coil and P2 phantom
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma2/QA_PRISMA2QA_20240809_180905_626000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat_coil = load(matfname);
    
else
    %@P3
    figoff = 2;
    % P1 coil & P1 phantom
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma3/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat = load(matfname);
    % P3 coil & P3 phantom
    pfolder = '/Volumes/Leopard-WS-barracuda2/OngoingResearch2/QADaily/Prisma3/QA_PRISMA3QA_20240809_182158_666000/EP2D_BOLD_P2_S2_5MIN_0003';
    matfname = [pfolder '/sigstat.mat'];
    P3sigstat_coil = load(matfname);
end

%%
nz = size(P3sigstat.phansignal,2);
nt = size(P3sigstat.phansignal,3);
nn = nz*nt;

x = [nz+1:nn];
%x = [nz+1:10*nz];
i = 1:length(x);
%{
figure(figoff+5); subplot(6,1,1); plot(i,P3sigstat.phansignal(1,x), i,P3sigstat_coil.phansignal(1,x),'LineWidth',2); axis tight; ylabel('phansignal');
figure(figoff+5); subplot(6,1,2); plot(i,P3sigstat.totnoisesignal(1,x), i,P3sigstat_coil.totnoisesignal(1,x),'LineWidth',2); axis tight;ylabel('totnoisesignal');
figure(figoff+5); subplot(6,1,3); plot(i,P3sigstat.aliasnoisesignal(1,x), i,P3sigstat_coil.aliasnoisesignal(1,x),'LineWidth',2); axis tight;ylabel('aliasnoisesignal');
figure(figoff+5); subplot(6,1,4); plot(i,P3sigstat.noisesignal(1,x), i,P3sigstat_coil.noisesignal(1,x),'LineWidth',2); axis tight;ylabel('noisesignal');
figure(figoff+5); subplot(6,1,5); plot(i,P3sigstat.ro_noisesignal(1,x), i,P3sigstat_coil.ro_noisesignal(1,x),'LineWidth',2); axis tight;ylabel('ro_noisesignal');
figure(figoff+5); subplot(6,1,6); plot(i,P3sigstat.pe_noisesignal(1,x), i,P3sigstat_coil.pe_noisesignal(1,x),'LineWidth',2); axis tight;ylabel('pe_noisesignal');
%}

figure(figoff+5); subplot(6,1,1); plot([P3sigstat.phansignal(1,x) P3sigstat_coil.phansignal(1,x)],'r','LineWidth',2); axis tight; ylabel('phansignal');
figure(figoff+5); subplot(6,1,2); plot([P3sigstat.totnoisesignal(1,x) P3sigstat_coil.totnoisesignal(1,x)],'r','LineWidth',2); axis tight; ylabel('totnoisesignal');
figure(figoff+5); subplot(6,1,3); plot([P3sigstat.aliasnoisesignal(1,x) P3sigstat_coil.aliasnoisesignal(1,x)],'r','LineWidth',2); axis tight; ylabel('aliasnoisesignal');
figure(figoff+5); subplot(6,1,4); plot([P3sigstat.noisesignal(1,x) P3sigstat_coil.noisesignal(1,x)],'r','LineWidth',2); axis tight; ylabel('corner noisesignal');
figure(figoff+5); subplot(6,1,5); plot([P3sigstat.ro_noisesignal(1,x) P3sigstat_coil.ro_noisesignal(1,x)],'r','LineWidth',2); axis tight; ylabel('ro noisesignal');
figure(figoff+5); subplot(6,1,6); plot([P3sigstat.pe_noisesignal(1,x) P3sigstat_coil.pe_noisesignal(1,x)],'r','LineWidth',2); axis tight; ylabel('pe noisesignal');