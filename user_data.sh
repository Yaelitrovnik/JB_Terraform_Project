#!/bin/bash
# -----------------------------
# Update system & install dependencies
# -----------------------------
apt-get update -y
apt-get install -y python3-pip python3-venv git curl

# Create webapp directory
mkdir -p /home/ubuntu/webapp
chown ubuntu:ubuntu /home/ubuntu/webapp

# -----------------------------
# Create Flask app with EC2 metadata
# -----------------------------
cat > /home/ubuntu/webapp/app.py << 'FLASKAPP'
import requests
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    public_ip = requests.get("http://169.254.169.254/latest/meta-data/public-ipv4").text
    instance_id = requests.get("http://169.254.169.254/latest/meta-data/instance-id").text
    instance_type = requests.get("http://169.254.169.254/latest/meta-data/instance-type").text

    return f"""
    AWS EC2 is running!<br>
    Public IP: {public_ip}<br>
    Instance ID: {instance_id}<br>
    Instance Type: {instance_type}<br>
    SSH key location: ${ssh_key_path}<br>
    Security Group ID: ${security_group_id}
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
FLASKAPP

# -----------------------------
# Install Python packages
# -----------------------------
pip3 install --upgrade pip
pip3 install flask boto3 requests

# -----------------------------
# Run Flask in background
# -----------------------------
nohup python3 /home/ubuntu/webapp/app.py > /home/ubuntu/webapp/flask.log 2>&1 &
