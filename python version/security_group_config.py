# security_group_config.py
import boto3
import requests
from botocore.exceptions import ClientError

def _get_public_ip_cidr():
    """Return student's public IP as CIDR (/32). Fallback to 0.0.0.0/0 if cannot detect."""
    try:
        ip = requests.get("https://checkip.amazonaws.com", timeout=5).text.strip()
        if ip:
            return ip + "/32"
    except Exception:
        pass
    # fallback (less secure)
    return "0.0.0.0/0"

def create_security_group(vpc_id, region="us-east-2", group_name="builder-yael-sg"):
    """
    Create (or reuse) security group in vpc_id.
    Inbound: SSH(22) and App(5001) restricted to student's public IP (/32).
    Outbound: allow all.
    Returns security group id.
    """
    ec2 = boto3.client("ec2", region_name=region)
    my_cidr = _get_public_ip_cidr()

    # check for existing SG with same name in same VPC
    try:
        existing = ec2.describe_security_groups(Filters=[
            {"Name": "group-name", "Values": [group_name]},
            {"Name": "vpc-id", "Values": [vpc_id]}
        ])["SecurityGroups"]
    except ClientError as e:
        raise

    if existing:
        sg_id = existing[0]["GroupId"]
        print(f"Reusing existing security group {group_name} ({sg_id}).")
        return sg_id

    resp = ec2.create_security_group(GroupName=group_name, Description="Builder SG (SSH+App restricted)", VpcId=vpc_id)
    sg_id = resp["GroupId"]

    # ingress rules
    ip_permissions = [
        {"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": my_cidr, "Description": "SSH from student"}]},
        {"IpProtocol": "tcp", "FromPort": 5001, "ToPort": 5001, "IpRanges": [{"CidrIp": my_cidr, "Description": "Flask app from student"}]},
    ]
    ec2.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=ip_permissions)

    # outbound is allowed by default in AWS SGs; if needed, ensure a rule exists (not necessary normally)
    print(f"Security group created: {sg_id} (restricted to {my_cidr})")
    return sg_id
