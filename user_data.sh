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
echo "SSH_KEY_PATH=${ssh_key_path}" >> /etc/environment
echo "SECURITY_GROUP_ID=${security_group_id}" >> /etc/environment
echo "INSTANCE_TYPE=${instance_type}" >> /etc/environment
echo "REGION=${region}" >> /etc/environment
echo "VPC_ID=${vpc_id}" >> /etc/environment

# ----------------------------
# Create app.py
# ----------------------------
cat > /home/ubuntu/webapp/app.py << 'EOF'
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
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>AWS EC2 Dashboard</title>
        <style>
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                justify-content: center;
                align-items: center;
                padding: 20px;
            }}
            .container {{
                background: white;
                border-radius: 20px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                padding: 40px;
                max-width: 700px;
                width: 100%;
            }}
            .header {{
                text-align: center;
                margin-bottom: 30px;
            }}
            .header h1 {{
                color: #333;
                font-size: 28px;
                margin-bottom: 10px;
            }}
            .status {{
                display: inline-block;
                background: #10b981;
                color: white;
                padding: 8px 20px;
                border-radius: 25px;
                font-size: 14px;
                font-weight: 600;
            }}
            .info-grid {{
                display: grid;
                gap: 20px;
                margin-top: 30px;
            }}
            .info-item {{
                background: #f8fafc;
                padding: 20px;
                border-radius: 12px;
                border-left: 4px solid #667eea;
                transition: transform 0.2s, box-shadow 0.2s;
            }}
            .info-item:hover {{
                transform: translateX(5px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }}
            .info-label {{
                color: #64748b;
                font-size: 12px;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 8px;
            }}
            .info-value {{
                color: #1e293b;
                font-size: 16px;
                font-weight: 500;
                word-break: break-all;
            }}
            .footer {{
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 2px solid #e2e8f0;
                color: #64748b;
                font-size: 14px;
            }}
            .aws-logo {{
                font-size: 40px;
                margin-bottom: 10px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="aws-logo">☁️</div>
                <h1>AWS EC2 Dashboard</h1>
                <span class="status">✅ Running</span>
            </div>
            
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Public IP Address</div>
                    <div class="info-value">{public_ip}</div>
                </div>
                
                <div class="info-item">
                    <div class="info-label">SSH Key Location</div>
                    <div class="info-value">{ssh_key_path}</div>
                </div>
                
                <div class="info-item">
                    <div class="info-label">Security Group ID</div>
                    <div class="info-value">{security_group_id}</div>
                </div>
                
                <div class="info-item">
                    <div class="info-label">Instance Type</div>
                    <div class="info-value">{instance_type}</div>
                </div>
                
                <div class="info-item">
                    <div class="info-label">AWS Region</div>
                    <div class="info-value">{region}</div>
                </div>
                
                <div class="info-item">
                    <div class="info-label">VPC ID</div>
                    <div class="info-value">{vpc_id}</div>
                </div>
            </div>
            
            <div class="footer">
                🚀 Flask Application Running on Port 5001
            </div>
        </div>
    </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

# ----------------------------
# Create systemd service for Flask
# ----------------------------
cat > /etc/systemd/system/flaskapp.service << 'EOF'
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