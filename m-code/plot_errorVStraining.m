clear;
clc;

%%% Initialization
Nt = 16;
Nr = 16;
total_num_of_clusters = 2;
total_num_of_rays = 3;
Np = total_num_of_clusters*total_num_of_rays;
L = 2;
snr_range = 30;
subSamplingRatio_range = [0.2 0.4 0.8];
Imax = 120;
maxRealizations = 10;
T = 100;

error_mcsi = zeros(maxRealizations,1);
error_omp = zeros(maxRealizations,1);
error_vamp = zeros(maxRealizations,1);
error_twostage = zeros(maxRealizations,1);

mean_error_mcsi = zeros(length(subSamplingRatio_range), length(snr_range));
mean_error_omp =  zeros(length(subSamplingRatio_range), length(snr_range));
mean_error_vamp =  zeros(length(subSamplingRatio_range), length(snr_range));
mean_error_twostage =  zeros(length(subSamplingRatio_range), length(snr_range));

for snr_indx = 1:length(snr_range)
  snr = 10^(-snr_range(snr_indx)/10);
  snr_db = snr_range(snr_indx);
  
  for sub_indx=1:length(subSamplingRatio_range)

   for r=1:maxRealizations
   disp(['realization: ', num2str(r)]);

    [H,Ar,At] = wideband_mmwave_channel(L, Nr, Nt, total_num_of_clusters, total_num_of_rays);
    Dr = 1/sqrt(Nr)*exp(-1j*(0:Nr-1)'*2*pi*(0:Nr-1)/Nr);
    Dt = 1/sqrt(Nt)*exp(-1j*(0:Nt-1)'*2*pi*(0:Nt-1)/Nt);
    [Y, Abar, Zbar, W] = wideband_hybBF_comm_system_training(H, Dr, Dt, T, snr);
    Gr = size(W'*Dr, 2);
    Gt = size(Abar, 1);
    % Random sub-sampling
    indices = randperm(Nr*T);
    sT = round(subSamplingRatio_range(sub_indx)*Nr*T);
    indices_sub = indices(1:sT);
  	Omega = zeros(Nr, T);
    Omega(indices_sub) = ones(sT, 1);
    OY = Omega.*Y;
    sT2 = round(subSamplingRatio_range(sub_indx)*T);
    Phi = kron(Abar(:, 1:sT2).', W'*Dr);
    y = vec(Y(:,1:sT2));
    
    % VAMP sparse recovery
    disp('Running VAMP...');
    s_vamp = vamp(y, Phi, snr, 100*L);
    S_vamp = reshape(s_vamp, Gr, Gt);
    error_vamp(r) = norm(S_vamp-Zbar)^2/norm(Zbar)^2
    if(error_vamp(r)>1)
        error_vamp(r) = 1;
    end
       
    
    % Sparse channel estimation
    disp('Running OMP...');
    s_omp = OMP(Phi, y, 100*L);
    S_omp = reshape(s_omp, Gr, Gt);
    error_omp(r) = norm(S_omp-Zbar)^2/norm(Zbar)^2      
    if(error_omp(r)>1)
        error_omp(r)=1;
    end
% 
% 
    
%     
% 
%     % Two-stage scheme matrix completion and sparse recovery
%     disp('Running Two-stage-based Technique..');
%     X_twostage_1 = mc_svt(H, OH, Omega, Imax);
%     s_twostage = vamp(vec(X_twostage_1), kron(conj(Dt), Dr), 0.001, 2*L);
%     X_twostage = Dr*reshape(s_twostage, Nr, Nt)*Dt';
%     error_twostage(r) = norm(H-X_twostage)^2/norm(H)^2;
%     
    % ADMM matrix completion with side-information
    disp('Running ADMM-based MCSI...');
    rho = 0.001;
    tau_S = 1/norm(OY, 'fro')^2;
    [~, Y_mcsi] = mcsi_admm(OY, Omega, W'*Dr, Abar, Imax, rho*norm(OY, 'fro'), tau_S, rho, Y, Zbar);
    S_mcsi = pinv(W'*Dr)*Y_mcsi*pinv(Abar);
    error_mcsi(r) = norm(S_mcsi-Zbar)^2/norm(Zbar)^2

   end

    mean_error_mcsi(sub_indx, snr_indx) = mean(error_mcsi);
    mean_error_omp(sub_indx, snr_indx) = mean(error_omp);
    mean_error_vamp(sub_indx, snr_indx) = mean(error_vamp);
    mean_error_twostage(sub_indx, snr_indx) = mean(error_twostage);

  end

end


figure;
p11 = semilogy(subSamplingRatio_range, (mean_error_omp(:, 1)));hold on;
set(p11,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Black', 'MarkerFaceColor', 'Black', 'Marker', '>', 'MarkerSize', 8, 'Color', 'Black');
p12 = semilogy(subSamplingRatio_range, (mean_error_vamp(:, 1)));hold on;
set(p12,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Blue', 'MarkerFaceColor', 'Blue', 'Marker', 'o', 'MarkerSize', 8, 'Color', 'Blue');
% p13 = semilogy(snr_range, (mean_error_twostage(1, :)));hold on;
% set(p13,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Cyan', 'MarkerFaceColor', 'Cyan', 'Marker', 's', 'MarkerSize', 8, 'Color', 'Cyan');
p14 = semilogy(subSamplingRatio_range, (mean_error_mcsi(:, 1)));hold on;
set(p14,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Green', 'MarkerFaceColor', 'Green', 'Marker', 'h', 'MarkerSize', 8, 'Color', 'Green');
 
legend({'OMP [4]', 'VAMP [12]', 'Proposed'}, 'FontSize', 12, 'Location', 'Best');
 
xlabel('sub-sampling ratio');
ylabel('NMSE (dB)')
grid on;set(gca,'FontSize',12);
 
savefig(strcat('results/errorVStraining.fig'))