output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.builder_sg.id
}

output "private_key_path" {
  description = "Local path where the private SSH key was saved"
  value       = local_file.private_key_file.filename
}
