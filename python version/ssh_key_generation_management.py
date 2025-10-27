# ssh_key_generation_management.py
import boto3
import os
import stat
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from botocore.exceptions import ClientError

def generate_ssh_key(key_name="builder-key", key_file=None, region="us-east-2"):
    """
    Generate a 4096-bit RSA private key locally and import public key to AWS.
    Returns (key_name, key_file_path).
    """
    if key_file is None:
        key_file = os.path.expanduser("~/.ssh/builder_key.pem")

    # generate private key
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption()
    )

    # write private key to file securely (no printing of the key)
    os.makedirs(os.path.dirname(key_file), exist_ok=True)
    with open(key_file, "wb") as f:
        f.write(private_pem)
    os.chmod(key_file, stat.S_IRUSR | stat.S_IWUSR)  # 0o600

    # create public key in OpenSSH format
    public_key_openssh = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ).decode("utf-8")

    # upload public key to AWS (import_key_pair)
    ec2 = boto3.client("ec2", region_name=region)
    try:
        # delete if exists (idempotent)
        ec2.delete_key_pair(KeyName=key_name)
    except ClientError:
        pass

    ec2.import_key_pair(KeyName=key_name, PublicKeyMaterial=public_key_openssh)
    print(f"SSH key '{key_name}' imported to AWS. Private key saved at: {key_file}")
    return key_name, key_file
