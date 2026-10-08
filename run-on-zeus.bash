#!/usr/bin/env bash
#SBATCH --time=10 # should take ~150s. give 10min

verb() { [ -z ${VERBOSE:-} ] || return; echo $@; }
source /raidzeus/singularity/setup.bash
OUTROOT=/raidzeus/derivatives/projs/QC/out/
[[ $# -eq 0 || $* =~ ^-+h ]] && echo "USAGE: $0 [all|/path/to/dir]\nREDO=1 DRYRUN=1 NO_SLURM=1 ONLYONE=1" && exit 0

[[ $1 == all ]] && FILES=(/disk/mace2/scan_data/homeless/*Prisma*QC/20*/*/ep2d_*) || FILES=("$@")
for dcmd in "${FILES[@]}"; do 
  ! test -d "$dcmd" && echo "ERROR: bad input dir '$dcmd' DNE" >&2 && continue
  ! [[ $dcmd =~ /[^/]+(Prisma[0-9])[^/]*/([0-9.-]+)/.*\.([0-9]+)$ ]] && echo "no study/date/seq in $dcmd" && continue
  study=${BASH_REMATCH[1]}; ymd=${BASH_REMATCH[2]}; seqno=${BASH_REMATCH[3]}
  desc=${ymd}-${study}-${seqno}
  outdir=$OUTROOT/$desc
  [[ -r $outdir/stats.json && -z "${REDO:-}" ]] && verb "# have $outdir" && continue

  if [ -z "${SLURM_JOB_ID:-}" -a -z "${NO_SLURM:-}" ]; then
    echo "# [$(date)] $outdir"
    log=$outdir/slurm.log
    dryrun mkdir -p $outdir
    # TODO check squeue |grep $desc
    dryrun sbatch --job-name="$desc" --output="$log" --error="$log" \
	    "$0" "$dcmd"
  else
    echo "start $(date +%F-%H:%M\ %s) ${HOSTNAME:-} $dcmdir"
    dryrun singularity run \
         --mount "type=bind,src=$dcmd,dst=/in,ro"  \
         -B "$outdir:$outdir:rw" \
       ./mrrcqa.1.5.3.20260303.sif "/in" ${SHOW_PLOT:-0} "$outdir"
    echo "finish $(date +%F-%H:%M\ %s) $? $outdir"
  fi

  [[ -n "${ONLYONE:-}" ]] &&  break || :
done
