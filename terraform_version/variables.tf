variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region to deploy resources"
}

variable "private_key_path" {
  type        = string
  description = "Absolute path to save SSH private key (example: C:/Users/user/.ssh/builder_key.pem)"
}

variable "key_name" {
  type        = string
  default     = "builder-key"
  description = "Name for the AWS EC2 Key Pair"
}
