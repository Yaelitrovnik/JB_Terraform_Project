variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region to deploy into"
}

variable "key_name" {
  type        = string
  default     = "builder-key"
  description = "Name of the key pair in AWS"
}

variable "private_key_path" {
  type        = string
  description = "Absolute local path to save the generated private key "
  validation {
    condition     = can(regex("^/", var.private_key_path))
    error_message = "private_key_path must be an absolute path (start with '/'). "
  }
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type"
}

variable "create_igw" {
  type        = bool
  default     = false
  description = "If true, create and attach an Internet Gateway + route table for the VPC (use with care)"
}
