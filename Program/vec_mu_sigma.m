function [mu, sigma] = vec_mu_sigma(data, mask, dims)
    % vectorize masking - calc mean and std using mask count
    %                     after clearing values not in the mask
    % use like
    % [phan(1,:), phan(2,:)] = vec_mu_sigma(DATA,mask3d,[1 2])
    mask = double(mask == 1);
    n = squeeze(sum(mask, dims));
    sm = squeeze(sum(data .* mask, dims));
    mu = sm ./ n;

    sumsq = squeeze(sum(data.^2 .* mask, dims));
    sigma = squeeze(sqrt( (sumsq - sm.^2./n) ./ (n - 1)));
end
