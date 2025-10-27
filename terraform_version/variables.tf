# variables.tf

variable "key_name" {
  description = "Name of the SSH key pair for EC2 instance"
  type        = string
  default     = "builder-key"
}

variable "private_key_path" {
  description = "Absolute path to save SSH private key (example: C:/Users/user/.ssh/builder_key.pem)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04"
  type        = string
  default     = ""  # optional, if you want to override
}

