#!/bin/bash
# ----------------------------
# Update & install packages
# ----------------------------
apt-get update -y
apt-get install -y python3-pip python3-venv git

# ----------------------------
# Create webapp folder
# ----------------------------
mkdir -p /home/ubuntu/webapp
chown ubuntu:ubuntu /home/ubuntu/webapp

# ----------------------------
# Create app.py with EC2 metadata
# ----------------------------
cat > /home/ubuntu/webapp/app.py << 'EOF'
import requests
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    public_ip = requests.get("http://169.254.169.254/latest/meta-data/public-ipv4").text
    return f"""AWS EC2 is running!
Public IP: {public_ip}"
SSH Key Location: {ssh_key_path}
Security Group ID: {security_group_id}
Flask is running on port 5001"""
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

# ----------------------------
# Install Python dependencies
# ----------------------------
pip3 install --user flask boto3 requests

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
ExecStart=/usr/bin/python3 -m flask run --host=0.0.0.0 --port=5001
Restart=always
Environment="PATH=/home/ubuntu/.local/bin"
Environment="FLASK_APP=/home/ubuntu/webapp/app.py"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Flask service
systemctl daemon-reload
systemctl enable flaskapp
systemctl start flaskapp

# ----------------------------
# Output instance info
# ----------------------------
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "--------------------------------------"
echo "EC2 Public IP: $PUBLIC_IP"
echo "SSH Key Location: ${ssh_key_path}"
echo "Security Group ID: ${security_group_id}"
echo "Flask is running on port 5001"
echo "--------------------------------------"

# Run Flask app in the background at startup
nohup python3 /home/ubuntu/webapp/app.py > /home/ubuntu/webapp/flask.log 2>&1 &
