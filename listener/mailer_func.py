import smtplib
from tomllib import load

def mailer(email_toml):
    # Open the file in binary read mode ("rb")
    with open(email_toml, "rb") as et:
        config = load(et)

    # Accessing data like a normal dictionary
    pipeline_name = (config["pipeline_name"])
    from_add =  (config["from"])
    to_add = (config["to"])
    message = (config["msg"])

    # smtp_host = '128.147.59.133' # mrrc specific host
    smtp_host = "pitt-edu.mail.protection.outlook.com" # upmc-edu.mail.protection.outlook.com
    srv = smtplib.SMTP(smtp_host)

    # SMTP.sendmail(from_addr, to_addrs, msg, mail_options=(), rcpt_options=())¶
    srv.sendmail( from_add, to_add, message)

#mailer("email.toml")
