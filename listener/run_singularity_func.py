import os
import sys

""" Function takes in singularity container, output directory, and dicom directory. 
It checks if the container is a .sif and the dicom directory exists. 
Then it runs the container on the dicom. 
This function does not check if the file is a dicom.

*How to use: python run_singularity_func.py container.sif directory dicom_file
"""

def run_singularity(container, outdir,  dcmd):

    # Checks
    if not container.endswith("sif"):
        raise ValueError(f"Container {container} does not contain a .sif file")
    if not os.path.isdir(dcmd):
        raise ValueError(f"File directory {dcmd} does not exist")
    if not os.path.isdir(outdir):
        raise ValueError(f"Directory {outdir} does not exist")

    # Terminal command
    return os.system(f'singularity run '
            f'--mount "type=bind,src={dcmd},dst={dcmd},ro" '
                     f'-B "{outdir}:{outdir}:rw" '
                     f'{container} {dcmd} 0 {outdir}'
                     )

def dry_run():
    dcmd = "/raidzeus/src/fw-mrrcqa/input/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/"
    container = " /raidzeus/singularity/images/mrrcqa-ml-1.6.1.20261011.sif"
    outdir = "/tmp/example_out"
    run_singularity(container, outdir, dcmd)


if __name__ == "__main__":
    dry_run()
    """"
    container = sys.argv[1]
    outdir = sys.argv[2]
    dcmd = sys.argv[3]
    run_singularity(container, outdir, dcmd)
    """
