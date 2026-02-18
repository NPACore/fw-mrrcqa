function ret = na0(x)
% NA0 - if x is cell type, remove NA and str2num other values
% could use readtable(..., 'TreatAsMissing', ["NA"]) with newer MATLAB
    ret = x;
    if ~contains(class(x),{'cell'})
        return
    end
    nl = length(x);
    ret = zeros(nl,1);
    for l=1:nl
        if ~contains(x{l},{'NA' 'na'})
            ret(l) = str2num(x{l});
        end
    end
end
