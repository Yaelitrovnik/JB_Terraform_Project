# main.py
import boto3
import sys
from ssh_key_generation_management import generate_ssh_key
from security_group_config import create_security_group
from instance_creation import (
    get_default_vpc,
    get_public_subnet_from_vpc,
    ensure_internet_gateway,
    ensure_public_route,
    create_ec2_instance
)

def main():
    region = "us-east-2"
    print("Starting deployment in region:", region)
    ec2 = boto3.client("ec2", region_name=region)

    try:
        # 1. Generate ssh key locally and import public key to AWS
        print("\n[1] SSH key generation & import")
        key_name, key_file = generate_ssh_key(key_name="builder-key", region=region)

        # 2. Determine VPC and subnet (public)
        print("\n[2] Locating VPC and public subnet")
        vpc_id = get_default_vpc(region=region)
        subnet_id = get_public_subnet_from_vpc(vpc_id, region=region)

        # 3. Ensure IGW and route so subnet is public
        print("\n[3] Ensuring internet gateway and route")
        igw_id = ensure_internet_gateway(vpc_id, region=region)
        ensure_public_route(subnet_id, igw_id, region=region)

        # 4. Create security group (restricted to student's IP)
        print("\n[4] Creating security group (SSH + Flask access)")
        sg_id = create_security_group(vpc_id, region=region)

        # 5. Launch EC2 and deploy Flask app
        print("\n[5] Launching EC2 instance and deploying Flask app")
        instance_id, public_ip, region = create_ec2_instance(key_name, vpc_id, subnet_id, sg_id, region=region)

        # 6. Final output shown locally
        print("\n" + "=" * 60)
        print("🎉 DEPLOYMENT COMPLETE 🎉")
        print("=" * 60)
        print(f"🆔 Instance ID: {instance_id}")
        print(f"🌍 Public IP: {public_ip}")
        print(f"🔐 SSH Key Path: {key_file}")
        print(f"🛡️ Security Group ID: {sg_id}")
        print(f"🔗 Flask App URL: http://{public_ip}:5001")
        print(f"💻 SSH Command: ssh -i {key_file} ubuntu@{public_ip}")
        print("=" * 60)
        print("Note: The Flask app reads metadata and will also show these fields at the web URL above.")
    except Exception as e:
        print("❌ Deployment failed:", e)
        sys.exit(1)

if __name__ == "__main__":
    main()
