#! /bin/bash
yum update -y
yum install python3 -y
pip3 install flask
pip3 install flask_mysql
yum install git -y
TOKEN="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"
USER=toptasc
cd /home/ec2-user/ && git clone https://$TOKEN@github.com/$USER/m6a-contacts.git
python3 /home/ec2-user/m6a-contacts/phonebook-app.py
