import flywheel
import os.path
import numpy as np
from datetime import datetime
from matplotlib import pyplot as plt

import coil

fw = flywheel.Client()
acqs = fw.files.find('project.label=~QA,acquisition.label=~qa_fid_uc_upw,name=~zip', limit=1e10)
print(f"total {len(acqs)} matches for qa_fid_uc_upw on flywheel")
all_scans = {} # key per scanner

# read in all data from flywheel and get FFT for all channels in all sequences
for f in acqs:
    study = f.info.get('StudyDescription').replace('Brain^','')
    day = f.info.get('InstanceCreationDate')
    name = f.name
    outname=os.path.join("qa_fid", study,day,name)
    if not os.path.isfile(outname):
        print(f"fetching {outname}")
        os.makedirs(os.path.dirname(outname), exist_ok=True)
        f.download(outname)

    if not study in all_scans.keys():
        all_scans[study] = []

    all_scans[study].append({'day': day, 'time': f.info.get("AcquisitionTime"),
                             'fname': outname, 'name': name,
                             'data': coil.fft_acqdir(outname)})

# generate a per channel template fft (mean) for each scanner
# get correlation of template with each
def channel_cor(x: np.ndarray, t: np.ndarray):
    """
    correlation per row of matching 2d matrix.
    :param x: input 64x2048 channel by fft value
    :param t: template(mean) 64x2048 channel by fft value
    :return: 64x1 correation per channel
    """
    return np.stack([np.corrcoef(x[i,:], t[i,:])[0,1] for i in range(x.shape[0])])

scan_info = {}
for study in all_scans.keys():
    fft_data = [x['data'] for x in all_scans[study]]
    fft = np.abs(np.stack(fft_data, axis=2))
    template = np.mean(fft, axis = 2)
    study_cor = [channel_cor(fft[:,:,i], template) for i in range(fft.shape[2])]
    scan_info[study]  = {'template': template, 'cor': np.stack(study_cor, axis=1)}
# template
fg, axes = plt.subplots(3,1)
fg.suptitle("Scanner Coil Template")
for i,study in enumerate(sorted(scan_info.keys())):
    tmpl_2d = scan_info[study]['template']
    sset = coil.norm_subset(tmpl_2d)
    im = axes[i].imshow(sset)
    axes[i].set_title(study)
    axes[i].set_xticks([0,sset.shape[1]//2, sset.shape[1]-1], [1024-50, 1024,1024+50])

# correlation
fg, axes = plt.subplots(1,3)
fg.suptitle('Correlation with scanner template')
for i,study in enumerate(sorted(scan_info.keys())):
    ax = axes[i]
    cor_data = scan_info[study]['cor'] #TODO: MAKE A COPY. otherwise will modify data
    #data[data<.8] = 0
    im = ax.imshow(cor_data, vmin=0, vmax=1)
    ax.set_title(study)
    days = [datetime.strptime(x['day'], "%Y%m%d").strftime("%m-%d")
            for x in all_scans[study]]
    ax.set_xticks(np.arange(len(days)))
    ax.set_xticklabels(days, rotation=90)
cbar = fg.colorbar(im, ax=axes, orientation="horizontal", fraction=.04)

import pandas as pd
import seaborn as sns

def combine_long(cor_data, study):
    d = pd.DataFrame(cor_data)
    # NB. all_scans global!
    d.columns = [datetime.strptime(x['day'] + " " + x['time'][0:6], "%Y%m%d %H%M%S") for x in all_scans[study]]
    d['channel'] = np.arange(64)+1
    df_long = pd.melt(d, id_vars=['channel'], var_name='date', value_name='corr')
    df_long['scanner'] = study
    return df_long

d = pd.concat([combine_long(scan_info[study]['cor'], study)
               for study in sorted(scan_info.keys())]).reset_index(drop=True)

g = sns.FacetGrid(data=d, col="scanner")
g.map_dataframe(sns.lineplot,    x='date', y='corr', hue='channel', marker=None, errorbar=None, estimator=None, alpha=.2,)
g.map_dataframe(sns.scatterplot, x='date', y='corr', hue='channel', marker='o')
for a in g.axes.flat:
    a.set_xticklabels(a.get_xticklabels(), rotation=45, ha='right') # ha='right' adjusts horizontal alignment
plt.suptitle("Correlation to template by date")

g_bychan = sns.FacetGrid(data=d, col="scanner")
d['date_from'] = [(x - d['date'].min()).days for x in d['date']]
g_bychan.map_dataframe(sns.scatterplot, x='channel', y='corr', hue='date_from', marker='o', palette="crest")
#sns.move_legend(g_bychan, "upper left")
plt.legend(title="day")
plt.suptitle("Correlation to template by channel")


plt.figure()
cnt = d.groupby(['channel','scanner']).\
    agg(rat=('corr', lambda x: np.count_nonzero(x<.8)/len(x)),
        avg_corr=('corr', 'mean'),
        total=('corr',lambda x: x.shape[0])).\
        reset_index().sort_values('rat',ascending=False)

ax_rat = sns.scatterplot(cnt, x='channel', y='rat', hue='avg_corr', style='scanner', size='total')
cnt_bad = cnt.query('rat >.2')
for r in cnt_bad.iterrows():
    r = r[1]
    ax_rat.text(r['channel'],r['rat'], r['channel'])

#sns.move_legend(ax, 'lower right')
plt.legend(bbox_to_anchor=(1, 1), loc='upper left', borderaxespad=0)
plt.ylabel("ratio cor < .8")
plt.title('How often channels do not match the template')


plt.figure()
ch_stats = pd.concat([pd.DataFrame({
    'max': scan_info[study]['template'].max(axis=1),
    'pos': scan_info[study]['template'].argmax(axis=1),
    'mean': scan_info[study]['template'].max(axis=1),
    'scanner': study,
    'channel':(np.arange(64)+1)})
                      for study in sorted(scan_info.keys())])

ax_chstats = sns.scatterplot(ch_stats, x='channel', y='max', style='scanner', hue='pos')
plt.title('Max value and position of max for each channel')


# plt.get_fignums()
plt.show()
