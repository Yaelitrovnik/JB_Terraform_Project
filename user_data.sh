#!/bin/bash
# ----------------------------
# Update & install packages
# ----------------------------
sudo apt-get update -y
sudo apt-get install -y python3-pip python3-venv git
sudo pip3 install flask boto3 requests

# ----------------------------
# Create webapp folder
# ----------------------------
mkdir -p /home/ubuntu/webapp
chown ubuntu:ubuntu /home/ubuntu/webapp

# ----------------------------
# Pass Terraform variables as environment variables
# ----------------------------
echo "export SSH_KEY_PATH=${ssh_key_path}" >> /etc/environment
echo "export SECURITY_GROUP_ID=${security_group_id}" >> /etc/environment
echo "export INSTANCE_TYPE=${instance_type}" >> /etc/environment
echo "export REGION=${region}" >> /etc/environment
echo "export VPC_ID=${vpc_id}" >> /etc/environment

# ----------------------------
# Create app.py
# ----------------------------
cat > /home/ubuntu/webapp/app.py << EOF
import os
import requests
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    try:
        public_ip = requests.get("http://169.254.169.254/latest/meta-data/public-ipv4", timeout=1).text
    except Exception:
        public_ip = "Unavailable"

    ssh_key_path = os.getenv("SSH_KEY_PATH", "Unknown")
    security_group_id = os.getenv("SECURITY_GROUP_ID", "Unknown")
    instance_type = os.getenv("INSTANCE_TYPE", "Unknown")
    region = os.getenv("REGION", "Unknown")
    vpc_id = os.getenv("VPC_ID", "Unknown")

    return f"""
    ✅ AWS EC2 Flask App is Running!<br>
    Public IP: {public_ip}<br>
    SSH Key Location: {ssh_key_path}<br>
    Security Group ID: {security_group_id}<br>
    Instance Type: {instance_type}<br>
    Region: {region}<br>
    VPC ID: {vpc_id}<br>
    Flask is running on port 5001
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

# ----------------------------
# Create systemd service for Flask
# ----------------------------
cat > /etc/systemd/system/flaskapp.service << EOF
[Unit]
Description=Flask Web App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/webapp
ExecStart=/usr/bin/python3 /home/ubuntu/webapp/app.py
Restart=always
EnvironmentFile=/etc/environment
StandardOutput=file:/home/ubuntu/webapp/flask.log
StandardError=file:/home/ubuntu/webapp/flask.log

[Install]
WantedBy=multi-user.target
EOF

# ----------------------------
# Enable and start Flask service
# ----------------------------
systemctl daemon-reload
systemctl enable flaskapp
systemctl start flaskapp