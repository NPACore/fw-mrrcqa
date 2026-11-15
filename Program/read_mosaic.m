function data3d = read_mosaic(mosaic_data,nx, mx,ny, my,nz)
% READ_MOSAIC - unstitch 2D mosaic into 3D matrix
% output is 3d data nx,ny,nz
% contsrcuted from mosaic patches in a grid mx x ny
% expect mosaic_data to be nx*mx, ny*my, like 94*7
data3d=zeros(nx,ny,nz);
assert(all(size(mosaic_data) == [nx*mx, ny*my])) % like 658, 658
for jj=1:my % row
    for ii=1:mx % column
        ll = ii + (jj-1)*mx; % z
        if ll > nz, break; end % mosaic not square. no data
        
        ir = (ii-1)*nx+1:ii*nx;
        jr = (jj-1)*ny+1:jj*ny;
        
        data3d(:,:,ll) = mosaic_data(jr,ir);
    end
end
end

