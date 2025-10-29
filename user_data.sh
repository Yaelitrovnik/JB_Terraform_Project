#!/bin/bash
apt-get update -y
apt-get install -y python3-pip python3-venv git
mkdir -p /home/ubuntu/webapp
chown ubuntu:ubuntu /home/ubuntu/webapp

cat > /home/ubuntu/webapp/app.py << 'FLASKAPP'
import boto3
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return "AWS EC2 is running! Public IP: " + "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
FLASKAPP

pip3 install flask boto3
pip3 install requests flask boto3
