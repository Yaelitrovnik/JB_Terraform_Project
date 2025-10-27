# output_info.py
from flask import Flask, render_template_string
import boto3
import requests
import os

app = Flask(__name__)

def get_imds_value(path, timeout=2):
    """Try IMDSv2 then IMDSv1 for a metadata path, return None on failure."""
    base = "http://169.254.169.254/latest"
    # try token
    try:
        token = requests.put(base + "/api/token", headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}, timeout=timeout).text
        headers = {"X-aws-ec2-metadata-token": token}
        return requests.get(base + "/meta-data/" + path, headers=headers, timeout=timeout).text
    except Exception:
        try:
            return requests.get(base + "/meta-data/" + path, timeout=timeout).text
        except Exception:
            return None

@app.route("/")
def home():
    # attempt to get instance metadata
    instance_id = get_imds_value("instance-id") or "Unavailable"
    public_ip = get_imds_value("public-ipv4") or "Unavailable"
    region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-2"))

    # use boto3 to fetch SG id (requires instance role with describe_instances)
    sg_id = "Unavailable"
    try:
        ec2 = boto3.client("ec2", region_name=region)
        details = ec2.describe_instances(InstanceIds=[instance_id])
        inst = details["Reservations"][0]["Instances"][0]
        sgs = inst.get("SecurityGroups", [])
        if sgs:
            sg_id = sgs[0].get("GroupId", "Unavailable")
    except Exception:
        sg_id = "Unavailable"

    html = """
    <html>
      <head><title>EC2 Deployment Info</title></head>
      <body style="font-family: Arial, sans-serif; margin: 30px;">
        <h1>✅ EC2 Flask App is Running</h1>
        <ul>
          <li><b>Instance ID:</b> {{ instance_id }}</li>
          <li><b>Public IP:</b> {{ public_ip }}</li>
          <li><b>Security Group ID:</b> {{ sg_id }}</li>
          <li><b>App Port:</b> 5001</li>
        </ul>
      </body>
    </html>
    """
    return render_template_string(html, instance_id=instance_id, public_ip=public_ip, sg_id=sg_id)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
