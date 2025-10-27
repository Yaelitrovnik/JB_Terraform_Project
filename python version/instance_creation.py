# instance_creation.py
import boto3
import base64
import time
import os

def get_default_vpc(region="us-east-2"):
    """Return a VPC id (prefer default)."""
    ec2 = boto3.client("ec2", region_name=region)
    vpcs = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])["Vpcs"]
    if vpcs:
        return vpcs[0]["VpcId"]
    vpcs = ec2.describe_vpcs()["Vpcs"]
    if vpcs:
        return vpcs[0]["VpcId"]
    raise Exception("No VPC found in region " + region)

def get_public_subnet_from_vpc(vpc_id, region="us-east-2"):
    """Return a subnet id that can assign public IPs; fallback to first."""
    ec2 = boto3.client("ec2", region_name=region)
    resp = ec2.describe_subnets(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}, {"Name": "state", "Values": ["available"]}])
    subnets = resp.get("Subnets", [])
    if not subnets:
        raise Exception("No subnets found for VPC " + vpc_id)
    for s in subnets:
        if s.get("MapPublicIpOnLaunch"):
            return s["SubnetId"]
    # fallback
    return subnets[0]["SubnetId"]

def ensure_internet_gateway(vpc_id, region="us-east-2"):
    ec2 = boto3.client("ec2", region_name=region)
    igws = ec2.describe_internet_gateways(Filters=[{"Name": "attachment.vpc-id", "Values": [vpc_id]}])["InternetGateways"]
    if igws:
        return igws[0]["InternetGatewayId"]
    igw = ec2.create_internet_gateway()["InternetGateway"]
    ec2.attach_internet_gateway(InternetGatewayId=igw["InternetGatewayId"], VpcId=vpc_id)
    return igw["InternetGatewayId"]

def ensure_public_route(subnet_id, igw_id, region="us-east-2"):
    ec2 = boto3.client("ec2", region_name=region)
    # find route table associated with subnet
    rts = ec2.describe_route_tables(Filters=[{"Name": "association.subnet-id", "Values": [subnet_id]}])["RouteTables"]
    if rts:
        rt_id = rts[0]["RouteTableId"]
    else:
        subnet_info = ec2.describe_subnets(SubnetIds=[subnet_id])["Subnets"][0]
        vpc_id = subnet_info["VpcId"]
        rts_all = ec2.describe_route_tables(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}])["RouteTables"]
        main_rt = None
        for rt in rts_all:
            for assoc in rt.get("Associations", []):
                if assoc.get("Main"):
                    main_rt = rt
                    break
            if main_rt:
                break
        if not main_rt:
            raise Exception("No main route table found for VPC " + vpc_id)
        rt_id = main_rt["RouteTableId"]

    # add 0.0.0.0/0 if missing
    rt_info = ec2.describe_route_tables(RouteTableIds=[rt_id])["RouteTables"][0]
    if not any(r.get("DestinationCidrBlock") == "0.0.0.0/0" for r in rt_info.get("Routes", [])):
        ec2.create_route(RouteTableId=rt_id, DestinationCidrBlock="0.0.0.0/0", GatewayId=igw_id)

def create_ec2_instance(key_name, vpc_id, subnet_id, sg_id, region="us-east-2"):
    """
    Launch EC2 in the given public subnet and deploy the Flask app by copying
    the local output_info.py into the instance via base64-encoded userdata.
    Returns instance_id, public_ip, region.
    """
    ec2 = boto3.client("ec2", region_name=region)

    # Get latest Ubuntu 22.04 LTS AMI (Canonical owner)
    images_resp = ec2.describe_images(
        Owners=["099720109477"],
        Filters=[{"Name": "name", "Values": ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]}]
    )["Images"]
    if not images_resp:
        raise Exception("Could not find Ubuntu 22.04 AMI in " + region)
    latest_ami = sorted(images_resp, key=lambda i: i["CreationDate"], reverse=True)[0]["ImageId"]

    # Read local output_info.py and base64 encode for safe transfer
    local_path = os.path.join(os.path.dirname(__file__), "output_info.py")
    with open(local_path, "r", encoding="utf-8") as f:
        flask_code = f.read()
    encoded = base64.b64encode(flask_code.encode("utf-8")).decode("utf-8")

    # build userdata (safe)
    user_data = f"""#!/bin/bash
set -eux
apt-get update -y
apt-get install -y python3 python3-pip
pip3 install --no-cache-dir flask boto3 requests

mkdir -p /home/ubuntu/app
# write the base64-decoded flask app file
echo '{encoded}' | base64 --decode > /home/ubuntu/app/output_info.py
chown ubuntu:ubuntu /home/ubuntu/app/output_info.py
chmod 644 /home/ubuntu/app/output_info.py

cat > /etc/systemd/system/webapp.service <<'EOF'
[Unit]
Description=Flask EC2 Info App
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/app
ExecStart=/usr/bin/python3 /home/ubuntu/app/output_info.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable webapp.service
systemctl start webapp.service
"""

    print(f"Using AMI {latest_ami} in region {region}")
    resp = ec2.run_instances(
        ImageId=latest_ami,
        MinCount=1,
        MaxCount=1,
        InstanceType="t3.medium",
        KeyName=key_name,
        NetworkInterfaces=[{
            "DeviceIndex": 0,
            "SubnetId": subnet_id,
            "AssociatePublicIpAddress": True,
            "Groups": [sg_id]
        }],
        TagSpecifications=[{"ResourceType": "instance", "Tags": [{"Key": "Name", "Value": "builder-yael"}]}],
        UserData=user_data
    )

    instance_id = resp["Instances"][0]["InstanceId"]
    print(f"Instance launched: {instance_id}. Waiting to be running...")
    waiter = ec2.get_waiter("instance_running")
    waiter.wait(InstanceIds=[instance_id], WaiterConfig={"Delay": 10, "MaxAttempts": 40})
    details = ec2.describe_instances(InstanceIds=[instance_id])
    inst = details["Reservations"][0]["Instances"][0]
    public_ip = inst.get("PublicIpAddress")
    return instance_id, public_ip, region
