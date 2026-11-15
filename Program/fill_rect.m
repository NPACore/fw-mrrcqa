function [x] = fill_rect(x,v,xxyys)
% FILL_RECT - given matrix x, fill with values v foreach element from cell of bounding boxes 2x2 mats
% used by make_masks()
   for i=1:length(xxyys)
       xxyy=xxyys{i};
       x1=xxyy(1,1); x2=xxyy(1,2); 
       y1=xxyy(2,1); y2=xxyy(2,2); 
       x(x1:x2,y1:y2) = v;
   end
end

%!test
%! assert sum(fill_rect(zeros(4,4), 1, {[1 2; 1 2], [3 4; 4 4]}),'all') == 6
