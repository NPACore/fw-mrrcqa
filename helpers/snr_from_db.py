#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "flywheel-sdk",
#     "seaborn",
# ]
# ///
"""
Pull ``snr`` from flywheel session data containers (info.snr).
Put there by the fw-mrrcqc gear or :py:func:`helpers.dbupdater`

BREAKING CHANGE(2026-10-08): default to fileystem json files instead of FW.
This addition is excessive. Could just read needed fields within R.
Python shim here was for flywheel API usage. No longer needed.
To move to R, would need to reimplment 'shim' split and parsing.

Wiki upload (wiki_upload.py) still easier with python.
plots.R calls that internally already.
"""
import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import logging
import glob
import re
import json

logging.basicConfig(level=os.environ.get("LOGLEVEL", "DEBUG").upper(),
format="%(asctime)s:%(levelname)s:%(name)s:%(message)s"
)

def project_from_fname(f):
    return os.path.basename(os.path.dirname(f))

class Session:
    """
    Matching old structure instead of using existing (cleaner) json files.
    This is crossing the river to get water.
    Like all_qc_sess and all_shim_and_snr
    """
    def __init__(self, stats_fname):
        """
        read matlab output json as if it was stored in flywheel DB.
        """
        self.project = project_from_fname(stats_fname)
        with open(stats_fname,'r') as f:
            stats = json.load(f)
            self.created = stats.get('date')
            self.info = {
                # columns as is. shim&XYZ values split below
                # which columns to take based on which were saved in flywhell
                # see ../Program/run.py::info =

                **{k: stats.get(k)
                   for k in ['skew', 'mean_mask_vol','skew','percent_voxels_max',
                             'shim', 'XYZ_uTm', 'XYZ2SC_uTm2']},
                # peak value to non pk name: snrpk, tsnrpk, aliaspk, bkoffpk
                **{k: stats.get(k+'pk')
                   for k in ['snr', 'tsnr', 'alias', 'bkoff']},
            }

class SNR:
    def __init__(self, globpatt="/raidzeus/derivatives/projs/QC/out/*/stats.json"):
        """
        breaking change 2026-10-08: globpatt default.
        use globpatt=None to revert to flywheel behavior
        """
        if globpatt:
            # project id to
            self.files = glob.glob(globpatt)
            # "project id" to scanner. extracing scanner name from folder
            self.p_lookup = {
                project_from_fname(x): re.search('Prisma[123]',x).group(0)
                for x in self.files
            }
            self.fw = None
        else:
            self.files = None
            import flywheel  # pip install flywheel-sdk
            self.fw = flywheel.Client()
            qc_projects = self.fw.projects.find("label=~Prisma.QA")

            # session only refers to project by id. get label lookup from project list
            self.p_lookup = {p.id: p.label.replace("QA", "") for p in qc_projects}
            # ['Prisma1', 'Prisma2', 'Prisma3']

    def all_qc_sess(self):
        if self.files:
            return [Session(fname) for fname in self.files]
        else:
            return all_qc_sess_fw(self)

    def all_qc_sess_fw(self):
        """
        :return:  list of all flywheel PrismaQA sessions
        """
    
        logging.info("Finding sessions")
        qc_sess = self.fw.sessions.find("project.label=~Prisma.QA")
        # info not populated by sessions.find?!
        assert len(qc_sess) > 0  # 294
        assert qc_sess[1].info == {}
        assert self.fw.get(qc_sess[1].id).info != {}  # {'snr': 243.2354653590228}

        # takes some time (minute?! for ~300 sessions)
        # 20250312 1.5 min for 481
        logging.info("Loading sessions")
        qc_sess = [self.fw.get(x.id) for x in qc_sess]
        logging.info("Loaded")
        return qc_sess

    def all_shim_and_snr(self, qc_sess = None) -> pd.DataFrame:
        """
        updated (20250312) version of all_snr for plotting in R.
        includes shim values
        """
        if qc_sess is None:
            qc_sess = self.all_qc_sess()
        snr = [
            {
                **s.info, # snr tsnr alias bkoff shim
                "date": s.created, #s.subject.created, 20250625: see same change in all_snr
                "scanner": self.p_lookup.get(s.project),
            }
            for s in qc_sess
            if s.info.get("snr")
        ]
        snr.sort(key=lambda x: x["date"])
        snr_df = pd.DataFrame(snr)

        #: shims are stored as an array of 8 elements
        #: see runp1.m::reportstatgrpstruct(cnt).SNR = stat.snrpk;
        #: NB. B0 is /1000 in matlab but not here
        shims = snr_df['shim'].apply(pd.Series)
        shims.columns=['X', 'Y', 'Z',
                       'X2', 'Y2', 'Z2', 'XY', 'S2',
                       'B0']

        # 20260304 - added XYZ_uTm (and XYZ2SC_uTm2, copy of shims[3:7])
        #            XYZ adjusted by gradient sensitivity to get in standardized uT/m units
        shimsXYZ = snr_df['XYZ_uTm'].apply(pd.Series)
        shimsXYZ.columns=['XuTm', 'YuTm', 'ZuTm']

        snr_expand = snr_df.drop(columns=['shim', 'XYZ_uTm', 'XYZ2SC_uTm2']).join(shims).join(shimsXYZ)
        return snr_expand

    def all_shim_and_snr_csv(self, fname) -> None:
        """
        wrapper to use in R for getting data
          using intermediate csv file b/c reticulate::py_to_r()'s
          dataframe has numpy.float64 columns that dont play well w/dplyr

        :param fname: csv output to write
        :returns: None -- expects R to reuse fname given
        """
        d = self.all_shim_and_snr()
        logging.info("Read in all snr. last date: %s", d.date.max())
        d.to_csv(fname)

    def all_snr(self) -> pd.DataFrame:
        """
        Fetch info.snr from all Prisma[123]QA projects' sessions.
        see all_shim_and_snr for snr +  shim values
        :return: dataframe with columns date, snr, scanner (project)
        """
        qc_sess = self.all_qc_sess()
        snr = [
            {
                # 20250625: was using 's.subject.created' but have multiple per day. get full datetime
                "date": s.created,
                "snr": s.info.get("snr"),
                "scanner": self.p_lookup.get(s.project),
            }
            for s in qc_sess
            if s.info.get("snr")
        ]
        snr.sort(key=lambda x: x["date"])
        snr_df = pd.DataFrame(snr)
        return snr_df


def plot_snr(snr_df: pd.DataFrame):
    """
    Plot with each scanner/project collored points.
    :param snr_df: dataframe from [helpers.snr_from_db.all_snr][]
    :return: matplotlib/seaborn plot like ![](snr_plot.png)
    """
    p = sns.scatterplot(x=snr_df.date, y=snr_df.snr, hue=snr_df.scanner)
    p.tick_params(axis="x", rotation=45)
    p.set_title("peak SNR")
    return p
    # plt.margins(.3,tight=True)


def main(upload=False, png=None, csv=None):
    """
    Read all values stored in flywheel and either
    1. plot :py:func:`plot_snr`
      a. show   (no file created)
      b. upload (temporary file on disk)
      c. save  (perminate file, not uploaded)
    2. write csv using py:func:`all_shim_and_snr_csv`
    """

    snr = SNR()
    if csv:
        snr.all_shim_and_snr_csv(csv)
        return

    snr_df = snr.all_snr()
    p = plot_snr(snr_df)
    # plt.show()
    if upload:
        from wiki_upload import upload_snr
        import tempfile

        with tempfile.NamedTemporaryFile() as f:
            logging.info("Saving temporoary plot %s", f.name)
            plt.savefig(f.name)
            logging.info("Uploading")
            upload_snr(f.name)
    else:
        if png:
            plt.savefig(png)
        else:
            plt.show()

    return snr_df


if __name__ == "__main__":
    import argparse

    parse = argparse.ArgumentParser(
        description="Plot or upload FW's DB SNR value from QC Phantom"
    )
    parse.add_argument("-u", "--upload", action="store_true", default=False, help="upload plot to wiki")
    parse.add_argument("--png", default=None, help="save png instead of showing")
    parse.add_argument("--csv", default=None, help="write csv instead of plotting")
    args = parse.parse_args()
    main(args.upload, args.png, args.csv)
