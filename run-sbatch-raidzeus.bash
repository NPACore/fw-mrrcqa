#!/usr/bin/env bash
#SBATCH --time=60
#SBATCH --ntasks 1 --cpus-per-task 2
#SBATCH --mem=3G

# should take ~150s on cerebro2. BUT
# Taking 50min on node07 -- slow singularity read? [start 20:50 to 21:36]

# only need 1 cpu. currently povisoning more than needed.
# expect < 1.5G of memory used. Also doubling
# without specifying any per-task and memory, one job would tie up a whole node 

# This script both (1) wraps around sbatch+singularity AND (2) is the sbatch script
# loops over input ep2d* QA EPI and calls itself to queue singularity

verb() { [ -z ${VERBOSE:-} ] || return; echo $@; }
source /raidzeus/singularity/setup.bash;
# 20261010 is raidzeus located cache responsible for slow execution times?
#  https://github.com/apptainer/singularity/issues/5376
# TODO: inspect --localstatedir
#export APPTAINER_WORKDIR="" APPTAINER_CACHEDIR="" APPTAINER_LOCALCACHEDIR="" SINGULARITY_CACHEDIR="" SINGULARITY_WORKDIR="" SINGULARITY_APPTAINER_LOCALCACHEDIR=""
export TMPDIR=/tmp

OUTROOT=/raidzeus/derivatives/projs/QC/out/
IMAGE="/raidzeus/singularity/images/mrrcqa-ml-1.6.1.20261011.sif"

case ${1:--help} in
  -h*|--h*) echo -e "USAGE: $0 [all|old|/path/to/dir]\nREDO=1 DRYRUN=1 NOSLURM=1 ONLYONE=1";  exit 0;;
  all) FILES=(/disk/mace2/scan_data/homeless/*Prisma*QC/20*/*/ep2d_*) ;;
  old) FILES=(/raidzeus/flywheel-qc-backup/Prisma*/Prisma*/SUBJECTS/*/SESSIONS/*/ACQUISITIONS/ep2d_bold_p2_s2_5min/FILES/1.*/);;
  *) FILES=("$@");;
esac

for dcmd in "${FILES[@]}"; do 
  ! test -d "$dcmd" && echo "ERROR: bad input dir '$dcmd' DNE" >&2 && continue
  if [[ $dcmd =~ /[^/]+(Prisma[0-9])[^/]*/([0-9.-]+)/.*\.([0-9]+)$ ]]; then
     study=${BASH_REMATCH[1]}; ymd=${BASH_REMATCH[2]}; seqno=${BASH_REMATCH[3]}
  # old QC from flywheel backup lik
  # /raidzeus/flywheel-qc-backup/Prisma1QA/Prisma1QA/SUBJECTS/PRISMA1QA20250331/SESSIONS/Brain^Prisma1QA*/ACQUISITIONS/ep2d_bold_p2_s2_5min/FILES/1.3.12.2.1107.5.2.43.67078.2025033106440849706901088.0.0.0
  # OR
  # /raidzeus/flywheel-qc-backup/Prisma3QA/Prisma3QA/SUBJECTS/QA PRISMA3/SESSIONS/Brain^Prisma3QA/ACQUISITIONS/ep2d_bold_p2_s2_5min/FILES/1.3.12.2.1107.5.2.43.167092.20250106230666656801105.0.0.0/
  elif [[ $dcmd =~ /Prisma([0-9])QA/.*FILES/[^/]*\.(202[0-9][0-9][0-9][0-9][0-9])[0-9]+\.0.0.0/ ]]; then
     study=Prisma${BASH_REMATCH[1]}; ymd=${BASH_REMATCH[2]};
     # no seqno stored in filename unless there's an additional run
     # eg. PRISMA1QA20250331/SESSIONS/Brain^Prisma1QA_1 => 1
     [[ $dcmd =~ SESSIONS/[^/]*QA_([0-9]+)/ ]] && seqno=${BASH_REMATCH[1]} || seqno=0
  else
     echo "no study/date/seq in $dcmd" && continue
  fi
  desc=${ymd}-${study}-${seqno}
  outdir=$OUTROOT/$desc
  [[ -r $outdir/stats.json && -z "${REDO:-}" ]] && verb "# have $outdir" && continue

  if [ -z "${SLURM_JOB_ID:-}" -a -z "${NOSLURM:-}" ]; then
    # check if we're already running this job. (search *-n*mame in queue. print no *-h*eader
    squeue -h -n "$desc" | grep -q . && echo "# $desc is running. skipping" && continue

    echo "# [$(date)] $outdir"
    log=$outdir/slurm.log
    dryrun mkdir -p $outdir
    dryrun sbatch --job-name="$desc" --output="$log" --error="$log" \
	    "$0" "$dcmd"
  else
    echo "start $(date +%F-%H:%M\ %s) ${HOSTNAME:-} $dcmdir $SLURM_JOB_ID $SLURM_JOB_NAME"
    # store as array to print to log too
    cmd=(singularity run \
         --mount "type=bind,src=$dcmd,dst=$dcmd,ro"  \
         -B "$outdir:$outdir:rw" \
	 $IMAGE "$dcmd" ${SHOW_PLOT:-0} "$outdir")
    echo "# $(printf "%q " "${cmd[@]}")"
    # actually run
    dryrun "${cmd[@]}"
    echo "finish $(date +%F-%H:%M\ %s) $? $outdir"
  fi

  [[ -n "${ONLYONE:-}" ]] &&  break || :
done
