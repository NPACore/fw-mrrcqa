# Matlab to Octave Code Port

## Dependencies
In addition to octave itself, the dicom functions used by the matlab code are in a separate octave package.
```
pkg install dicom -forge % fails, missing GDCM
yay -S octave-dicom # manage depens with system
```

## Testing

Octave has easier function testing. see {{gitlink("Program/readshimvalues.m")}}
```matlab
%!test
%! [ shimvalues .... ] = readshimvalues('...') ;
%! [lOffsetX ...] = num2cell(shimvalues){:};
%! assert(lOffsetX,  2865);
```

<!-- Not sure what the issue was or how this was resolved
## Changes
```
error: bar: Y must be numeric
error: called from
    __bar__ at line 38 column 5
    bar at line 122 column 18
    runQC at line 26 column 28
```
-->
