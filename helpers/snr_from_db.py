import subprocess
import flywheel # pip install flywheel-sdk
import pandas as pd
fw = flywheel.Client()
qc_projects = fw.projects.find("label=~Prisma.QA")

# session only refers to project by id. get label lookup from project list
p_lookup = {p.id: p.label.replace('QA','') for p in qc_projects}
# ['Prisma1', 'Prisma2', 'Prisma3']

qc_sess = fw.sessions.find("project.label=~Prisma.QA")
# info not populated by sessions.find?!
assert len(qc_sess) > 0 # 294
assert qc_sess[1].info == {}
assert fw.get(qc_sess[1].id).info != {}  # {'snr': 243.2354653590228}

# takes some time (minute?! for ~300 sessions)
qc_sess = [fw.get(x.id) for x in qc_sess]

snr = [
    {'date': s.subject.created,
     'snr': s.info.get('snr'),
     'scanner': p_lookup.get(s.project)}
    for s in qc_sess
    if s.info.get('snr')]
snr.sort(key=lambda x: x['date'])
snr_df = pd.DataFrame(snr)
import matplotlib.pyplot as plt
import seaborn as sns
p = sns.scatterplot(x=snr_df.date,
                    y=snr_df.snr,
                    hue=snr_df.scanner)
p.tick_params(axis='x', rotation=45)
p.set_title('peak SNR')
#plt.margins(.3,tight=True)
plt.savefig('/tmp/snr.png')
plt.show()


# https://www.dokuwiki.org/devel:xmlrpc#dokuwikilogin
# https://docs.python.org/3/library/xmlrpc.client.html#xmlrpc.client.ServerProxy.system.listMethods
# https://github.com/fmenabe/python-dokuwiki/blob/master/dokuwiki.py#L24
url = 'https://rad.pitt.edu/wiki/'
user = 'foran'
password = subprocess.run(['pass','work/pitt'],capture_output=True).stdout.decode().strip()

import base64
from xmlrpc.client import ServerProxy, Binary
import subprocess
auth =  "Basic " + base64.b64encode(f'{user}:{password}'.encode('utf-8')).decode()
header = [("Authorization", auth)]
proxy = ServerProxy(url + "lib/exe/xmlrpc.php", headers=header)
login = proxy.dokuwiki.login(user, password)
assert login
with open('/tmp/snr.png','rb') as img:
    img_data=img.read()
# base64.b64encode(img_data).decode('utf-8')
# pitt EWI F5/ASM blocked gives:
#   ssl.SSLEOFError: EOF occurred in violation of protocol (_ssl.c:2393)
res = proxy.wiki.putAttachment('mrrc_prismas_snr.png', Binary(img_data), {'ow':True})
