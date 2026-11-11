import os
import sys

#How to use: python3 run_singularity_func.py container.sif directory dicom_file

def run_singularity(container, dir,  file):
    if not container.endswith("sif"):
        raise ValueError(f"Container {container} does not contain a .sif file")

    file_path = os.path.join(dir, file)
    if not os.path.isfile(file_path):
        raise ValueError(f"File {file_path} does not exist")

    return os.system(f"singularity run {container} {file_path}")

if __name__ == "__main__":
    container = sys.argv[1]
    dir = sys.argv[2]
    file = sys.argv[3]
    run_singularity(container, dir, file)