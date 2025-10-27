output "instance_public_ip" {
  value       = aws_instance.builder_instance.public_ip
  description = "Public IP of EC2 instance"
}

output "private_key_path" {
  value       = var.private_key_path
  description = "Private SSH key location"
}

output "security_group_id" {
  value       = aws_security_group.builder_sg.id
  description = "Security Group ID"
}
