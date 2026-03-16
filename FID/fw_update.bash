getftime(){
   local file=${1:?input file}
   git diff --quiet HEAD -- "$file" &&
      git log -1 --format="%ct" -- "$file"  ||
      stat -c %Y "$file";
}
getfwtime(){
   local scanner=${1:?scanner} file=${2:?remote file}
   REMOTE_TIME=$(fw ls "fw://mrrc/$scanner/files/$file" |& sed -En 's/^.*KB (.*) files.*/\1/p')
	[ -z "$REMOTE_TIME" ] && REMOTE_TIME="Jan 01 1970 01:00" # make very old if MIA
   date --utc -d "$REMOTE_TIME" +"%s"
}

[[ $* =~ ^-h ]] && echo "USAGE: $0 [all|fwhm.py coil.py ...]" && exit 0
[[ $* =~ '^all' ]] && FILES=(fwhm.py coil.py) || FILES=("$@")

for file in "${FILES[@]}"; do
  ! test -r "$file" && echo "missing '$file', no file to upload!" && continue
  for scanner in Prisma1QA Prisma2QA Prisma3QA; do
   ltime=$(getftime "$file")
   rtime=$(getfwtime $scanner "$file")
   diff=$(perl -e "print $ltime - $rtime")
   echo "# $scanner/$file: l=$ltime $(date -d "@$ltime" +"%F %T"); r=$rtime $(date -d "@$rtime" +"%F %T") |  $diff"
   [ "$diff" -gt 120 ] &&
     dryrun fw upload "$file" fw://mrrc/$scanner ||
     echo "# not uploading $file, not new enough"
  done
done
