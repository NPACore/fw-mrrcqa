#!/usr/bin/env bash
set -eou pipefail
#
# run QA pipeline on fixed mask.
# use ants to align ref and apply to mask.
# calculate tSNR. extract averages for ROIs
# 20250821WF - init
#

export AFNI_NIFTI_TYPE_WARN=NO

[[ $# -lt 2 || "$*" =~ ^-h ]] && echo "USAGE: $0 input{/,.nii.gz,.zip} output/ tmp/" && exit 0

dcm_in=${1:?FW input zip file, dcm directory, or 4d nii image}
outdir=${2:-outputs/}
workdir=${3:-${TMPDIR:-/tmp}} #"/flywheel/v0/work/"

! command -v antsRegistrationSyN.sh  >/dev/null &&
  echo "ERROR: ANTs tools are not in PATH" &&
  exit 1
! command -v 3dmaskave  >/dev/null &&
  echo "ERROR: AFNI tools are not in PATH" &&
  exit 1

# absolute path to this script. used to find fixed files: $ref and $mask
scriptdir=$(cd "$(dirname "$0")"; pwd -P)

mkdir -p $workdir

echo "# $(date) start"
start_time=$(date +%s)

# dcm2niix -o input -f bullet_phantom_epi -z y input/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/
# 3dTstat -mean -prefix input/bullet_phantom_ref.nii.gz input/bullet_phantom_epi.nii.gz
ref=$scriptdir/ref/bullet_phantom_ref.nii.gz
! test -r "$ref" && echo "ERROR: alignment reference '$ref' is not found" && exit 1

# see Program/write_mask.m
mask=$scriptdir/ref/qa_masks_noshift.nii
! test -r "$mask" && echo "ERROR: snr ROI atlas/mask '$mask' is not found" && exit 1

region=(phan_erode bg noise readout phaseenc alias)
n=$(3dinfo -nt "$mask")
! [[ $n -eq ${#region[@]} ]] && echo "ERROR: $n regions in $mask, does not match ${regions[*]}" && exit 1


## make file
# TODO: set trap to remove tmp if dir exists
case $dcm_in in
   *nii|*nii.gz) in=$dcm_in;;
   *.zip) 
      tmp=$(mktemp -d $workdir/dcm2niix-XXXX)
      in=$tmp/phantom.nii.gz

      unzip -d $tmp $dcm_in
      indir=$(find $tmp \
         -type f \( -iname '*IMA' -or -iname '*.dcm' -or -iname 'MR*' \) \
         -exec dirname {} \; -quit| sed 1a)
      [ -z "$indir" -o ! -d "$indir" ] &&
         echo "ERROR: no dcms (*IMA, *dcm, MR*) in zip '$dcm_in' extracted to $tmp" >&2 &&
         exit 1

      dcm2niix -o $tmp/ -f phantom -z y $indir
      echo "# made $in" >&2;;
    *)
     ! test -d "$dcm_in" && echo "Expected input '$dcm_in' to be a .nii.gz, .zip, or dicom dir" && exit 1
      tmp=$(mktemp -d $workdir/dcm2niix-XXXX)
      in=$tmp/phantom.nii.gz

      dcm2niix -o $tmp/ -f phantom -z y $dcm_in
      echo "# made $in" >&2;;
esac

[ ! -r "$in" ] && echo "Failed to find or make nii image '$in'" && exit 1
echo "# working on input w/dims $(3dinfo -n4 $in)"
mean_in=$workdir/mean.nii.gz
#ImageMath 3 "$mean_in" mean "$in"

## tsnr
3dTstat -overwrite -mean -prefix "$mean_in" "$in"
3dTstat -overwrite -stdev -prefix "$workdir/stdev.nii.gz" "$in"  # raw sd

# may want to remove drift?
#3dDetrend -prefix "$workdir/det.nii.gz" -polort 4 "$in" # remove drift that otherwise inflates SD
#3dTstat -stdev -prefix "$tmp/det.stdev.nii.gz" "$tmp/det.nii.gz" #calcualte SD on detrended data

# tsnr = mean/stdev
3dcalc -overwrite \
   -m "$mean_in" -s "$workdir/stdev.nii.gz" \
   -expr 'm/s' -float -prefix "$workdir/tsnr.nii.gz"

# move reference into mean phantom of current scan. will do the same to the mask
# fixed is current, moving if reference (backwards)
# transform does not need to be ridgid. could be just transform? 't' instead of current 'r'
time antsRegistrationSyN.sh -d 3 -m "$ref" -f "$mean_in" -t r -o $workdir/rigid > $workdir/ants-SyN.log

# bring mask into current
antsApplyTransforms -e 3 -i "$mask" -r "$mean_in" -t $workdir/rigid0GenericAffine.mat -n NearestNeighbor -o $workdir/mask.nii.gz

n0=$((n-1))
for i in $(seq 0 $n0); do
   mask_at_roi=${workdir}/mask.nii.gz"[$i]"
   # average pre-computed tsnr in each roi.
   # 3dROIstats columns are fixed regardless of argument order
   #     Mean_1          NZcount_1       Min_1           Max_1           Med_1
   3dROIstats -quiet -nobriklab -nzvoxels -sigma -minmax -median -mask "$mask_at_roi" "$workdir/tsnr.nii.gz" |
      sed "s/^/${region[$i]}/" > $workdir/tsnr-${region[$i]}.txt

   # Average of each roi at each time. dont need for noise roi. use SD calc below
   [[ ${region[$i]} == "noise" ]] && continue
   3dmaskave -quiet -mask "$mask_at_roi" "$in" > $workdir/snr-${region[$i]}.txt
done

# stddev of noise mask for SNR denominator
noise_roi=${workdir}/mask.nii.gz"[5]"
3dROIstats -quiet -nobriklab -nomeanout -sigma -mask "$noise_roi" "$in" |sed 's/\t//' > $workdir/snr-noise-sd.txt

mkdir -p $outdir
echo -e "roi\tMean\tNZcount\tSigma\tMin\tMax\tMed" | tee $outdir/tsnr.tsv
cat $workdir/tsnr-*.txt |tee -a $outdir/tsnr.tsv


# SNR - want to divide by the roi averages by the sd of signal in the dedicated noise ROI
# we get mean, sd, min, max. but what we really want is mode after 120-bins
# [snrn,snrx] = hist(snr,120);
# [M,I] = max(snrn); stat.snrpk = snrx(I);
dm_stats(){
  # ordered so output columns to match tsnr. but no nzvoxels
   datamash mean 1 sstdev 1 min 1 max 1 median 1 |
      sed "s/^/${1:?roi}\t/"
}

noise_div(){ paste "${1:?timeseries}" $workdir/snr-noise-sd.txt | awk '{print $1/$2}'; }

echo -e "roi\tMean\tSigma\tMin\tMax\tMed" |tee  $outdir/snr.tsv
echo -e "roi\tBinCount\tBinStart\tBinEnd" |tee  $outdir/histmode_snr.tsv
for roi in 'phan_erode' 'alias' 'bg'; do
   noise_div $workdir/snr-$roi.txt | dm_stats $roi | tee -a $outdir/snr.tsv
   # 120 bin histogram peak
   noise_div $workdir/snr-$roi.txt | sort | ./hist_mode |sed "s/^/$roi\t/" | tee -a $outdir/histmode_snr.tsv
done
cat $workdir/snr-noise-sd.txt | dm_stats noise_sd | tee -a $outdir/snr.tsv

# save alignment matrix as text. QA protocol has phantom placement procedure.
# alignment should be near exact
ConvertTransformFile 3 $workdir/rigid0GenericAffine.mat $outdir/alignment.txt

echo "# $(date) finished in $(($(date +%s) - $start_time)) seconds"
#  mlr --tsv cat --filename then cut -f filename,roi,Med,Max output/* | column -t

# SNR is ratio of 
# noisesignal is dedicated noise ROI
# totnoisesignal is anything not phantom == background
#
# snr = phansignal(1,:)./noisesignal(2,:);
# alias = aliasnoisesignal(1,:)./noisesignal(2,:);
# background = totnoisesignal(1,:)./noisesignal(2,:);
# noise = noisesignal(2,:);
#
#maskbg1 = 1-mask(:); Ibg1 = find(maskbg1==1);
#totnoisesignal(1,ll,i) = mean(dataslice1(Ibg1)); totnoisesignal(2,ll,i) = std(dataslice1(Ibg1));
#background = totnoisesignal(1,:)./noisesignal(2,:);

#noiseroi1 = noiseroi(:); Inoise1 = find(noiseroi1==1);
#noisesignal(1,ll,i) = mean(dataslice1(Inoise1)); noisesignal(2,ll,i) = std(dataslice1(Inoise1));

#ALL_MASK(:,:,ll, idx.bg)         = reshape(maskbg1,nx,ny);
#ALL_MASK(:,:,ll, idx.noise)      = reshape(noiseroi1,nx,ny);
#
# snr peak is top hist value of mean in roi at slice (ll) and timepoint/file (i)
#    phansignal(1,ll,i) = mean(dataslice1(Iphan1)); phansignal(2,ll,i) = std(dataslice1(Iphan1));
# snr = phansignal(1,:)./noisesignal(2,:);
# [snrn,snrx] = hist(snr,120);
# [M,I] = max(snrn); stat.snrpk = snrx(I);
# 
#   info = {'snr': stats.get('snrpk'),
#           'tsnr': stats.get('tsnrpk'),
#           'shim': stats.get('shim'),
#           'alias': stats.get('aliaspk'),
#           'bkoff':stats.get('bkoffpk')}
