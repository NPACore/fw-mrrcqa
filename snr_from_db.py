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
plt.savefig('/tmp/snr.png')
plt.show()

# https://www.dokuwiki.org/devel:xmlrpc#dokuwikilogin
# https://docs.python.org/3/library/xmlrpc.client.html#xmlrpc.client.ServerProxy.system.listMethods
url = 'https://rad.pitt.edu/wiki/'

import base64
from xmlrpc.client import ServerProxy
user = 'npac'
password = '...' # todo read from secure file?
auth =  "Basic " + base64.b64encode(f'{user}:{password}'.encode('utf-8')).decode()
header = [("Authorization", auth)]
proxy = ServerProxy(url + "lib/exe/xmlrpc.php", headers=header)
login = proxy.dokuwiki.login(user, password)
assert login
with open('/tmp/snr.png','rb') as img:
    img_data=base64.b64encode(img.read())
res = proxy.wiki.putAttachment('mrrc_prismas_snr.png', img_data, {'ow':True})

import requests
import re
# No luck
upload = 'lib/exe/ajax.php?=undefined&ns=&mediaid=&call=mediaupload&qqfile=mrrc_prismas_snr.png&ow=true'
session = requests.Session()
with requests.Session() as session:
    response = session.post(url + "doku.php", data={'u': user, 'p': password})
    assert response.status_code == 403
    # Cookies are automatically stored in the session
    response = session.get(url + "lib/exe/mediamanager.php?ns=&edid=wiki__text")

    # security token is empty? needs javascript?
    sectok = re.search('sectok" value=.([^"]*?)',response.text)
    assert sectok
    print(sectok.group())
    # Subsequent requests will use the stored cookies
    #upload = {'mediamanager__upload_item0': open('/tmp/snr.png', 'rb')}
    upload = {'file':  '/tmp/snr.png'} # open('/tmp/snr.png', 'rb')}
    response = session.post(url + "lib/exe/ajax.php?ns=&mediaid=&call=mediaupload&qqfile=mrrc_prismas_snr.png&ow=true", files=upload)
