#!/usr/bin/env python
import base64
from xmlrpc.client import ServerProxy, Binary
import os
import subprocess
import logging

# https://www.dokuwiki.org/devel:xmlrpc#dokuwikilogin
# https://docs.python.org/3/library/xmlrpc.client.html#xmlrpc.client.ServerProxy.system.listMethods
# https://github.com/fmenabe/python-dokuwiki/blob/master/dokuwiki.py#L24
def upload_image(img_path, url = 'http://rad.pitt.edu/wiki/', user = 'foran'):
    password = os.environ.get('WIKIPASS') or subprocess.run(['pass','work/pitt'],capture_output=True).stdout.decode().strip()
    logging.debug("using password: %s", password)
    auth =  "Basic " + base64.b64encode(f'{user}:{password}'.encode('utf-8')).decode()
    header = [("Authorization", auth)]
    proxy = ServerProxy(url + "lib/exe/xmlrpc.php", headers=header)
    
    logging.info("logging in")
    login = proxy.dokuwiki.login(user, password)
    assert login
    
    with open(img_path,'rb') as img:
        img_data=img.read()
    
    logging.info("sending image")
    # base64.b64encode(img_data).decode('utf-8')
    # pitt EWI F5/ASM blocked gives:
    #   ssl.SSLEOFError: EOF occurred in violation of protocol (_ssl.c:2393)
    res = proxy.wiki.putAttachment('mrrc_prismas_snr.png', Binary(img_data), {'ow':True})

if __name__ == "__main__":
    upload_image('/tmp/snr.png')
