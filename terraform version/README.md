# AWS EC2 Flask Deployment (Terraform)

This Terraform project provisions an AWS EC2 instance that runs a Flask app which displays the instance details (Instance ID, Public IP, Security Group ID). The Terraform configuration preserves the behavior of the original Python project and includes improvements for security and reliability.

---

## Features

- Generates a 4096-bit RSA SSH key locally; private key saved at a local path you provide (permissions 0600).
- Imports the public key into AWS as an `aws_key_pair`.
- Creates a Security Group that allows inbound SSH (22) and Flask app (5001) only from your detected public IP (/32).
- Launches an Ubuntu 22.04 EC2 instance in a public subnet (if available) and injects the `output_info.py` Flask app using base64-encoded `user_data`.
- Creates an IAM role and instance profile (attached to the EC2) granting `ec2:DescribeInstances` so the Flask app can query AWS via `boto3` without credentials.
- Exposes outputs: `instance_id`, `public_ip`, `security_group_id`, and local `private_key_path`.

---

## Files

- `providers.tf`       - Provider configuration (AWS, tls, http, local, null)
- `variables.tf`       - Adjustable variables (region, key name, private key path, instance type, create_igw)
- `main.tf`            - Core resource definitions and user_data injection
- `output_info.py`     - Flask app to run on the instance (injected verbatim)
- `outputs.tf`         - Terraform outputs
- `requirements.txt`   - Python deps installed on the instance

---

## Prerequisites

- Terraform 1.0+ (recommended latest)
- AWS credentials (configured via environment or `~/.aws/credentials`)
- Python packages are installed on the EC2 instance by `user_data` (no local install required)
- Decide an **absolute** path for your private key (e.g., `/home/you/.ssh/builder_key.pem`)

---

## Usage

1. Place these files in a directory (example: `aws_flask_terraform/`), including `output_info.py`.
2. Edit `variables.tf` or pass variables via `-var` flags. *Important:* set `private_key_path` to an absolute path.
3. Initialize and apply:

```bash
terraform init
terraform apply
``` 
Type yes to confirm.

After apply, Terraform will output:

1. `instance_id`
2. `public_ip`
3. `security_group_id`
4. `private_key_path (local path only)`

Open the Flask app: 

```bash
http://<public_ip>:5001
``` 
## Security Notes

- The private key is stored locally only — Terraform will not print or store its contents in outputs. The path is provided so you can ssh into the instance.

- Security Group restricts inbound SSH and app port access to your detected public IP /32. If detection fails, the configuration falls back to 0.0.0.0/0 (editable behavior). You can change that in main.tf or set up strict policies in your environment.

## Teardown

To remove everything created by Terraform:

``` bash
terraform destroy
```

Also consider removing the generated private key if you no longer need it:

``` bash
rm /path/to/your/builder_key.pem
```

## Troubleshooting

If the Flask app fails, SSH into the instance and check systemd logs:

```bash
ssh -i /path/to/builder_key.pem ubuntu@<public_ip>
sudo journalctl -u webapp.service -n 300 --no-pager
```

If the instance cannot download packages, confirm the subnet has public internet access or run with `create_igw=true`.