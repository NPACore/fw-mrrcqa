"""
DONT USE. see xmlrpc in ./snr_from_db.py instead
here for posterity -- never worked
"""
url = 'https://wiki/'
user = ''
password = ''
image_path = '/tmp/snr.png'
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
    upload = {'file':  image_path} # open('/tmp/snr.png', 'rb')}
    response = session.post(url + "lib/exe/ajax.php?ns=&mediaid=&call=mediaupload&qqfile=mrrc_prismas_snr.png&ow=true", files=upload)
