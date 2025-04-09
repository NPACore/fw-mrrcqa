#!/usr/bin/env bash
#
# compare matlab with octave
#
# 20250408WF - init
#
example=v2/example/20250311
if [  ! -d $example ]; then
   fw download -o $example.zip \
     'fw://mrrc/Prisma1QA/PRISMA1QA  20250311/Brain^Prisma1QA/ep2d_bold_p2_s2_5min/files/1.3.12.2.1107.5.2.43.67078.2025031106293917518801088.0.0.0.dicom.zip' 
   unzip -d $example -j $example.zip
fi

mkscript() {
   # run dostats and record json output. save to $suffix
   # will run PLOTS if DOPLOTS is set
   suffix=${1:?save suffix}
   echo -n "addpath('Program'); try, "
   echo -n "stats = dostat('$example', ${DOPLOTS:=0}); json_str=jsonencode(stats); "
   echo -n "fid = fopen('v2/example-$suffix.json','w'); fprintf(fid, '%s', json_str); fclose(fid);"
   [ "${DOPLOTS}" -eq 1 ] && echo -n "combine_figures('v2/example-$suffix.pdf'); "
   echo -n "catch e, e, "
   echo -n "end; quit;"
}

Xvfb :99 &
pid=$!
sleep 1
export DISPLAY=:99
mkscript XXXX; echo # show what we'll run
matlab -nodesktop -nosplash  -r "$(mkscript matlab)"
octave --eval "$(mkscript octave)"
kill $pid
