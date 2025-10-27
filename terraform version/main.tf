locals {
  # trimmed detected IP and cidr building
  detected_ip = trimspace(data.http.my_ip.response_body)
  cidr_block  = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", local.detected_ip)) ? "${local.detected_ip}/32" : "0.0.0.0/0"
}

# detect student's public IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
  request_headers = {
    "User-Agent" = "terraform"
  }
  # small timeout defaults; provider handles errors -> fallback handled in locals
}

# generate RSA key locally
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# write private key to local filesystem (must provide absolute path)
resource "local_file" "private_key_file" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = var.private_key_path
  file_permission = "0600"
}

# ensure permissions (some platforms may ignore local_file's file_permission)
resource "null_resource" "fix_permissions" {
  triggers = {
    file = local_file.private_key_file.filename
  }

  provisioner "local-exec" {
    command     = "chmod 600 ${local_file.private_key_file.filename} || true"
    interpreter = ["/bin/bash","-c"]
  }
}

# import public key into AWS
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
  depends_on = [local_file.private_key_file]
}

# get default VPC(s)
data "aws_vpcs" "default" {
  filter {
    name   = "isDefault"
    values = ["true"]
  }
}

data "aws_vpcs" "all" {
  # fallback to all vpcs to pick first if default wasn't present
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  # prefer default vpc if found, otherwise first available
  vpc_id = length(data.aws_vpcs.default.ids) > 0 ? data.aws_vpcs.default.ids[0] : data.aws_vpcs.all.ids[0]
}

# find subnets in the chosen VPC
data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# inspect each subnet so we can prefer map_public_ip_on_launch
data "aws_subnet" "each" {
  for_each = toset(data.aws_subnets.vpc_subnets.ids)
  id       = each.value
}

locals {
  public_subnet_ids = [for s in data.aws_subnet.each : s.id if s.map_public_ip_on_launch]
  subnet_id_selected = length(local.public_subnet_ids) > 0 ? local.public_subnet_ids[0] : data.aws_subnets.vpc_subnets.ids[0]
}

# optional: create IGW + route table and association if requested
resource "aws_internet_gateway" "igw" {
  count  = var.create_igw ? 1 : 0
  vpc_id = local.vpc_id
  tags = {
    Name = "builder-yael-igw"
  }
}

resource "aws_route_table" "public_rt" {
  count  = var.create_igw ? 1 : 0
  vpc_id = local.vpc_id
  tags = {
    Name = "builder-yael-public-rt"
  }
}

resource "aws_route" "default_route" {
  count = var.create_igw ? 1 : 0
  route_table_id         = aws_route_table.public_rt[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

# optionally associate the route table to each subnet (use with care)
resource "aws_route_table_association" "assoc" {
  count = var.create_igw ? length(data.aws_subnets.vpc_subnets.ids) : 0
  subnet_id      = element(data.aws_subnets.vpc_subnets.ids, count.index)
  route_table_id = aws_route_table.public_rt[0].id
}

# security group restricted to detected ip (or 0.0.0.0/0 fallback)
resource "aws_security_group" "builder_sg" {
  name        = "builder-yael-sg"
  description = "Security group for builder-yael instance (SSH + Flask restricted)"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH from student"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.cidr_block]
  }

  ingress {
    description = "Flask app from student"
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = [local.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "builder-yael-sg"
  }
}

# find latest Canonical Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# encode the Flask app file to base64 for safe user_data injection
locals {
  output_info_base64 = base64encode(file("${path.module}/output_info.py"))
}

# IAM role and policy for the EC2 instance (allow describe instances)
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "builder-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_policy" "allow_describe_instances" {
  name        = "builder-allow-describe-instances"
  description = "Allow EC2 DescribeInstances for the instance Flask app"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.allow_describe_instances.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "builder-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = local.subnet_id_selected
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.builder_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "builder-yael"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update -y
    apt-get install -y python3 python3-pip
    pip3 install --no-cache-dir flask boto3 requests

    mkdir -p /home/ubuntu/app
    echo "${local.output_info_base64}" | base64 --decode > /home/ubuntu/app/output_info.py
    chown ubuntu:ubuntu /home/ubuntu/app/output_info.py
    chmod 644 /home/ubuntu/app/output_info.py

    cat > /etc/systemd/system/webapp.service <<'SRV'
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
    SRV

    systemctl daemon-reload
    systemctl enable webapp.service
    systemctl start webapp.service
  EOF
}
