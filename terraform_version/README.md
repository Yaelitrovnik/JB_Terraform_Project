# AWS EC2 + Flask Deployment with Terraform

This Terraform project automatically:

1. Generates an SSH key pair.
2. Creates a security group allowing:
   - SSH access (port 22) from your IP
   - Flask web app access (port 5001) from your IP
3. Launches an EC2 instance in the default VPC and a public subnet.
4. Deploys a Flask app via `user_data` which can be accessed at `http://<public_ip>:5001`.
5. Outputs:
   - EC2 Public IP
   - Security Group ID
   - Local path to SSH private key

---

## **Usage**

1. Ensure AWS CLI is configured:

```bash
aws configure
```

2. Initialize Terraform:

```bash
terraform init
```

3. Apply Terraform (enter path to save private key):

```bash
terraform apply
```

4. Enter your private_key_path when prompted, e.g.:

```swift
C:/Users/user/.ssh/builder_key.pem
```

5. Access Flask app:

```cpp
http://<EC2_PUBLIC_IP>:5001
```

6. SSH into the instance:

```bash
ssh -i "C:/Users/user/.ssh/builder_key.pem" ubuntu@<instance_public_ip>
```