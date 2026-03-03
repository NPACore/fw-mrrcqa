import subprocess
import flywheel
import os
import tempfile

fw = flywheel.Client()
ses_id = sys.argv[1] 
#ses_id='69a577cefd6a94887ba20535'
x = fw.get(ses_id)
# assume if sessions not in parents, this is a session not a acq
# add that the first file matchign ep2d in the containe we were given is the right one
if not  in 'session' in dcm_zip.parents.keys():
    dcm_zip = [x for x in x.acquisitions() if re.search('ep2d',x.label)][0].files[0]
else:
    dcm_zip = x

# tmp = tempfile.TemporaryDirectory()
with tempfile.TemporaryDirectory() as tmp:
    print(tmp.name)
    tmp_name = os.path.join(tmp.name, 'x.zip')
    dcm_zip.download(tmp_name)
    subprocess.run(["unzip","-j", "-d", tmp.name + "/dcm", tmp_name]) # get out of zip, junk paths to avoid nested dirs
    subprocess.run(["dcm2niix","-o", tmp.name, "-f", "epi", "-z", "y"]) # make nii for easy afni/fsl view
    os.environ['QA_SAVE_IMAGES']='1'
    os.makedirs(os.path.join(tmp.name,'out'), exist_ok=True)
    # run matlab -- will hang python. loads saves and loads all matlab vars
    subprocess.run(["matlab",#"-nodesktop",
                    "-nosplash", "-r", 
                    f"cd Program; dostat('{tmp.name}/dcm',1,'{tmp.name}/out'); load('{tmp.name}/out/sigstat.mat')"])
    # will remove tmp when closed
