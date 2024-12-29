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


def all_snr() -> pd.DataFrame:
    """
    Fetch info.snr from all Prisma[123]QA projects' sessions.
    :return: dataframe with columns date, snr, scanner (project)
    """
    fw = flywheel.Client()
    qc_projects = fw.projects.find("label=~Prisma.QA")

    # session only refers to project by id. get label lookup from project list
    p_lookup = {p.id: p.label.replace("QA", "") for p in qc_projects}
    # ['Prisma1', 'Prisma2', 'Prisma3']

    logging.info("Finding sessions")
    qc_sess = fw.sessions.find("project.label=~Prisma.QA")
    # info not populated by sessions.find?!
    assert len(qc_sess) > 0  # 294
    assert qc_sess[1].info == {}
    assert fw.get(qc_sess[1].id).info != {}  # {'snr': 243.2354653590228}

    # takes some time (minute?! for ~300 sessions)
    logging.info("Loading sessions")
    qc_sess = [fw.get(x.id) for x in qc_sess]

    snr = [
        {
            "date": s.subject.created,
            "snr": s.info.get("snr"),
            "scanner": p_lookup.get(s.project),
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

    snr_df = all_snr()
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
