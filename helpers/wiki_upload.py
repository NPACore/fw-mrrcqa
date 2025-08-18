#!/usr/bin/env python3
"""
We want to have a place to share SNR QC measures.
sftp upload is complicated by UPMC vs Pitt firewall.
Dokuwiki image upload is one alternative, but must be run from a whitelisted IP (eg. zeus or cerebro).

Other alternatives include wordpress (rad.pitt.edu) drupal/pantheon (mrrc.pitt.edu) or confluence.
sftp would be best, but we are not on the same network. The firewall blocks access.

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
from typing import Optional


class DokuWiki:
    """
    Class to hold th authenticated XML-RPC connection object: py:var:`DokuWiki.proxy`
    """

    user = None
    password = None
    wiki_url = ""
    proxy = None

    def __init__(
        self, wiki_url: Optional[str], user: Optional[str] = None, password: Optional[str] = None
    ):
        """
        :param wiki_url: root url of wiki. Trailing slash important
        :param user: wiki user name
        :param password: matching password
        """
        if not wiki_url:
            wiki_url = os.environ['WIKIROOT']
        if not wiki_url:
            raise Exception("no wiki location? use WIKIROOT environmental variable")

        self.wiki_url = wiki_url
        self.set_creds(user, password)  # set user and password
        self.login()  # set `proxy` XML-RPC interface

    def set_creds(self, user, password):
        """
        set credentials if not already defined
        use environment variables: WIKIUSER and/or WIKIPASS
        or try to get from 'pass' command
        :sideffect: will maybe update self.user and self.password
                    and will raise an Exception if they are not set
        """
        if not user:
            user = os.environ.get("WIKIUSER", "npac")
        self.user = user

        if not self.password:
            self.password = (
                os.environ.get("WIKIPASS")
                or subprocess.run(["pass", "wiki/npac"], capture_output=True)
                .stdout.decode()
                .strip()
            )
        # error if still not set
        # logging.debug("using password: %s", password)
        assert self.user
        assert self.password

    def login(self):
        """
        login to dokuwiki site. expects user and password likely set by set_creds
        :sideeffect: sets `proxy` as XML-RPC interface
        """
        creds = f"{self.user}:{self.password}"
        auth = "Basic " + base64.b64encode(creds.encode("utf-8")).decode()
        header = [("Authorization", auth)]
        self.proxy = ServerProxy(self.wiki_url + "lib/exe/xmlrpc.php", headers=header)

        login = self.proxy.dokuwiki.login(self.user, self.password)
        logging.info(f"wiki log in test for {self.user}: '{login}'")
        assert login

    def upload_file(self, local_path: str, wiki_name=None, binary=True):
        """
        Upload an image to a dokuwiki server using XML-RPC (must be enabled for user on wiki side).
        For more robust XMLRPC interaction, see the python-dokuwiki module on pypi
        :param local_path: file location of file (image) to upload
        :param wiki_name: what to call the upload on the wiki (default is basename of local_path)
        """

        read_spec = "rb" if binary else "r"
        with open(local_path, read_spec) as fh:
            file_data = fh.read()

        if wiki_name is None:
            wiki_name = os.path.basename(local_path)

        logging.info("sending file '%s' as '%s'", local_path, wiki_name)
        # base64.b64encode(file_data).decode('utf-8')
        # pitt EWI F5/ASM blocked gives:
        #   ssl.SSLEOFError: EOF occurred in violation of protocol (_ssl.c:2393)
        if binary:
            data = Binary(file_data)
        else:
            #data = base64.b64encode(file_data.encode()) #.decode("utf-8")
            data = file_data

        # ow set to overwrite existing file on wiki side
        res = self.proxy.wiki.putAttachment(wiki_name, data, {"ow": True})
        return res


def upload_snr(img_path: str):
    """
    Wrap py:func:`DokuWiki.upload_file` to specifically upload SNR.
    username and password are pulled from py:func:`set_creds` defaults (npac w/'pass' cmd)
    :param img_path: path of image to upload. likely a temporary file. See snr_from_db.py
    """

    dw = DokuWiki("http://rad.pitt.edu/wiki/")
    return dw.upload_file(img_path, wiki_name="mrrc_prismas_snr.png")


if __name__ == "__main__":
    import sys

    # upload first argument if given (eg '/tmp/snr.png')
    # otherwise use default
    to_upload = "PhantomQC.png" if len(sys.argv) < 2 else sys.argv[1]

    upload_snr(to_upload)
