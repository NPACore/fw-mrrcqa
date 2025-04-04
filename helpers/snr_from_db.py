#!/usr/bin/env python3
"""
Pull ``snr`` from flywheel session data containers (info.snr).
Put there by the fw-mrrcqc gear or :py:func:`helpers.dbupdater`
"""
import flywheel  # pip install flywheel-sdk
import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import logging

logging.basicConfig(level=os.environ.get("LOGLEVEL", "DEBUG").upper(),
format="%(asctime)s:%(levelname)s:%(name)s:%(message)s"
)

class SNR:
    def __init__(self):
        self.fw = flywheel.Client()
        qc_projects = self.fw.projects.find("label=~Prisma.QA")

        # session only refers to project by id. get label lookup from project list
        self.p_lookup = {p.id: p.label.replace("QA", "") for p in qc_projects}
        # ['Prisma1', 'Prisma2', 'Prisma3']

    def all_qc_sess(self):
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

    def all_shim_and_snr(self) -> pd.DataFrame:
        """
        updated (20250312) version of all_snr for plotting in R.
        includes shim values
        """
        qc_sess = self.all_qc_sess()
        snr = [
            {
                **s.info, # snr tsnr alias bkoff shim
                "date": s.subject.created,
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
        snr_expand = snr_df.drop(columns=['shim']).join(shims)
        return snr_expand

    def all_shim_and_snr_csv(self, fname) -> None:
        """
        wrapper to use in R for getting data
          using intermediate csv file b/c reticulate::py_to_r()'s
          dataframe has numpy.float64 columns that dont play well w/dplyr

        :param fname: csv output to write
        :returns: None -- expects R to reuse fname given
        """
        self.all_shim_and_snr().to_csv(fname)

    def all_snr(self) -> pd.DataFrame:
        """
        Fetch info.snr from all Prisma[123]QA projects' sessions.
        see all_shim_and_snr for snr +  shim values
        :return: dataframe with columns date, snr, scanner (project)
        """
        qc_sess = self.all_qc_sess()
        snr = [
            {
                "date": s.subject.created,
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


def main(upload=False, png=None):

    snr = SNR()
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


if __name__ == "__main__":
    import argparse

    parse = argparse.ArgumentParser(
        description="Plot or upload FW's DB SNR value from QC Phantom"
    )
    parse.add_argument("-u", "--upload", action="store_true", default=False)
    parse.add_argument("--png", default=None)
    args = parse.parse_args()
    main(args.upload, args.png)
