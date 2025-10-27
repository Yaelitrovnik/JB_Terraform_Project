# Terraform AWS EC2 + Flask Deployment

This project deploys an Ubuntu 22.04 EC2 instance using Terraform, including:

- SSH key generation
- Security group with SSH and Flask port
- Automatic Flask app deployment on the instance
- Outputs public IP, private key path, and security group ID

## Usage

1. Configure AWS CLI:

```bash
aws configure
```

2. Initialize Terraform:

```bash
terraform init
```

3. Apply Terraform (enter path to save private key):

```bash
terraform apply -var "private_key_path=C:/Users/user/Desktop/JB_Terraform_Project/terraform_version/builder_key.pem"
```

4. Access Flask app:

```bash
http://<EC2_PUBLIC_IP>:5001
```