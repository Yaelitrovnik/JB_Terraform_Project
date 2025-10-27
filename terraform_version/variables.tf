variable "private_key_path" {
  type        = string
  description = "Absolute path to save SSH private key"
}

variable "create_igw" {
  type        = bool
  default     = false
  description = "Create Internet Gateway + route table if true"
}
