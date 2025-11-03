# ----------------------------
# Generate SSH key
# ----------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_file" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = var.private_key_path
  file_permission = "0600"
}

resource "aws_key_pair" "builder_key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# ----------------------------
# Get user public IP
# ----------------------------
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# ----------------------------
# Existing VPC & Subnet
# ----------------------------
data "aws_vpc" "jbp" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "jbp_public" {
  filter {
    name   = "tag:Name"
    values = [var.public_subnet_name]
  }

  vpc_id = data.aws_vpc.jbp.id
}

# ----------------------------
# Security Group
# ----------------------------
resource "aws_security_group" "builder_sg" {
  name        = "builder-sg"
  description = "Security group for builder-yael EC2"
  vpc_id      = data.aws_vpc.jbp.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "Flask app access"
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------
# Latest Ubuntu AMI
# ----------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ----------------------------
# EC2 Instance with Flask app
# ----------------------------
resource "aws_instance" "builder_instance" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.builder_key.key_name
  subnet_id                   = data.aws_subnet.jbp_public.id
  vpc_security_group_ids      = [aws_security_group.builder_sg.id]
  associate_public_ip_address = true
  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "builder-yael"
  }
}