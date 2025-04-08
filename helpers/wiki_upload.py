#!/usr/bin/env python3
"""
We want to have a place to share SNR QC measures.
sftp upload is complicated by UPMC vs Pitt firewall.
Dokuwiki image upload is one alternative, but must be run from a whitelisted IP (eg. zeus or cerebro).

Other alternatives include wordpress (rad.pitt.edu) drupal/pantheon (mrrc.pitt.edu) or confluence.

Here we're using dokuwiki's XMLRPC interface.
This must be explicitly enabled and the connecting user must be whitelisted in dokuwiki's admin interface.
I also tried using 'requests' directly with the html forum/POST but uploads returned 200 despite not updating the file.
See wiki_http.py for the unused attempt.


Useful links

- https://www.dokuwiki.org/devel:xmlrpc#dokuwikilogin
- https://docs.python.org/3/library/xmlrpc.client.html#xmlrpc.client.ServerProxy.system.listMethods
- https://github.com/fmenabe/python-dokuwiki/blob/master/dokuwiki.py#L24

"""

import base64
from xmlrpc.client import ServerProxy, Binary
import os
import subprocess
import logging

def upload_image(img_path: str, user: str, password: str, wiki_name=None, wiki_url = 'http://rad.pitt.edu/wiki/'):
    """
    Upload an image to a dokuwiki server using XML-RPC (must be enabled for user on wiki side).
    For more robust XMLRPC interaction, see the python-dokuwiki module on pypi
    :param img_path: file location of image to upload
    :param user: wiki user name
    :param password: matching password
    :param wiki_name: what to call the upload on the wiki (default is basename of img_path)
    :param wiki_url: root url of wiki. Trailing slash important
    """
    auth =  "Basic " + base64.b64encode(f'{user}:{password}'.encode('utf-8')).decode()
    header = [("Authorization", auth)]
    proxy = ServerProxy(wiki_url + "lib/exe/xmlrpc.php", headers=header)
    
    logging.info(f"wiki log in test for {user}")
    login = proxy.dokuwiki.login(user, password)
    assert login
    
    with open(img_path,'rb') as img:
        img_data=img.read()

    if wiki_name is None:
        wiki_name = os.path.basename(img_path)
    
    logging.info("sending image '%s' as '%s'", img_path, wiki_name)
    # base64.b64encode(img_data).decode('utf-8')
    # pitt EWI F5/ASM blocked gives:
    #   ssl.SSLEOFError: EOF occurred in violation of protocol (_ssl.c:2393)
    res = proxy.wiki.putAttachment(wiki_name, Binary(img_data), {'ow':True})
    return res

def upload_snr(img_path: str):
    """
    Wrap py:func:`upload_image` to specifically upload SNR.
    :param img_path: path of image to upload. likely a temporary file. See snr_from_db.py
    """

    password = os.environ.get('WIKIPASS') or subprocess.run(['pass', 'wiki/npac'],capture_output=True).stdout.decode().strip()
    #logging.debug("using password: %s", password)

    user = os.environ.get('WIKIUSER', 'npac')
    return upload_image(img_path, user, password, wiki_name='mrrc_prismas_snr.png')

if __name__ == "__main__":
    upload_snr('/tmp/snr.png')
