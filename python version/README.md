# 🚀 AWS EC2 Flask Deployment Automation

This project automates the **creation and configuration of an AWS EC2 instance**, complete with SSH access, a secure security group, and an auto-deployed **Flask web app** that displays live instance information.

It’s designed for DevOps learning and AWS automation practice — combining **Python + Boto3 + EC2 + systemd + Flask**.

---

## 🧩 Features

✅ **1. Instance Creation**
Launches an Ubuntu 22.04 EC2 instance in a **public subnet** with auto-assigned public IP and installs the Flask app automatically using EC2 **User Data**.

✅ **2. SSH Key Generation & Management**
Creates a new RSA SSH key pair locally (private key stored securely), and uploads the public key to AWS.
The private key is never exposed in AWS — only its local path is shown.

✅ **3. Security Group Configuration**
Creates (or reuses) a security group restricted to your **current public IP**:

* Allows **SSH (22)** for remote login
* Allows **HTTP (5001)** for the Flask app
* Blocks all other inbound access
* Allows all outbound traffic (for software installation and updates)

✅ **4. Flask App Deployment**
The Flask app (`output_info.tf`) runs on port `5001` and displays:

* Instance ID
* Public IP
* Security Group ID
* Running Port

✅ **5. Automated Output Summary**
At the end of the run, the script prints all relevant info:

* Public IP
* SSH key path
* Security Group ID
* Flask URL
* SSH connection command

---

## 🏗️ Project Structure

```
aws_flask_project/
├── main.tf                            # Main orchestrator
├── instance_creation.tf               # EC2 creation + app deployment
├── ssh_key_generation_management.tf   # SSH key pair generation & upload
├── security_group_config.tf           # Security group setup
├── output_info.tf                     # Flask app (runs inside EC2)
├── requirements.txt                   # Dependencies
└── README.md                          # Documentation
```

---

## ⚙️ Prerequisites

* **Python 3.8+**
* **AWS account** with programmatic access
* AWS credentials configured locally (`aws configure`)
* IAM permissions for:

  * `ec2:Describe*`
  * `ec2:Create*`
  * `ec2:RunInstances`
  * `ec2:ImportKeyPair`
  * `ec2:DeleteKeyPair`

---

## 📦 Installation

1. **Clone or download the repository**

   ```bash
   git clone https://github.com/Yaelitrovnik/JB_Terraform_Project.git
   cd aws_flask_project
   ```

2. **Install dependencies**

   ```bash
   pip install -r requirements.txt
   ```

3. **Verify AWS credentials**

   ```bash
   aws sts get-caller-identity
   ```

---

## 🚀 Usage

Run the deployment with:

```bash
python3 main.tf
```

The script will:

1. Generate and import an SSH key pair
2. Create (or reuse) a secure security group
3. Launch a public EC2 instance with Ubuntu
4. Deploy a Flask web app on port `5001`
5. Output connection details

Example output:

```
🎉 DEPLOYMENT COMPLETE 🎉
🆔 Instance ID: i-0a123456b789cdef0
🌍 Public IP: 54.173.11.123
🔐 SSH Key Path: ~/.ssh/builder_key.pem
🛡️ Security Group ID: sg-0123abcd
🔗 Flask App URL: http://54.173.11.123:5001
💻 SSH Command: ssh -i ~/.ssh/builder_key.pem ubuntu@54.173.11.123
```

---

## 🌐 Access the Flask App

After the instance is running (usually 1–2 minutes), open in your browser:

```
http://<Public-IP>:5001
```

You’ll see a live dashboard like this:

| Field             | Example             |
| ----------------- | ------------------- |
| Instance ID       | i-0a123456b789cdef0 |
| Public IP         | 54.173.11.123       |
| Security Group ID | sg-0123abcd         |
| App Port          | 5001                |

---

## 🔐 Security Notes

* The SSH key (`builder_key.pem`) is **stored locally** at `~/.ssh/` and **never** printed or uploaded.
* The security group restricts inbound traffic to **your detected public IP** only.
* If IP detection fails, it temporarily falls back to `0.0.0.0/0` (you can modify this behavior).
* Outbound traffic is allowed for system updates and `pip` installations.

---

## 🧠 How It Works (Internally)

1. **`ssh_key_generation_management.tf`**

   * Creates a 4096-bit RSA key
   * Saves private key locally
   * Imports public key into AWS

2. **`security_group_config.tf`**

   * Gets your public IP from `checkip.amazonaws.com`
   * Creates a security group restricted to that IP

3. **`instance_creation.tf`**

   * Fetches latest Ubuntu 22.04 AMI
   * Encodes `output_info.tf` in Base64
   * Passes it as EC2 **User Data**
   * Sets up Flask as a **systemd service**

4. **`output_info.tf`**

   * Runs automatically on EC2 startup
   * Fetches metadata (instance ID, IP)
   * Uses `boto3` to get SG ID
   * Displays everything via Flask

5. **`main.tf`**

   * Calls all other scripts in order
   * Prints a summary with SSH and web info

---

## 🧹 Cleanup (to avoid extra AWS charges)

When you’re done testing:

```bash
# Find and terminate instance
aws ec2 terminate-instances --instance-ids <InstanceID>

# Delete the security group
aws ec2 delete-security-group --group-id <SecurityGroupID>

# Delete the imported key pair
aws ec2 delete-key-pair --key-name builder-key
rm ~/.ssh/builder_key.pem
```


