output "instance_name" { 
  value = aws_instance.builder_instance.tags["Name"] 
  description = "Name tag of the EC2 instance"
}

output "instance_id" { 
  value = aws_instance.builder_instance.id 
  description = "EC2 instance ID" 
}

output "instance_public_ip" {
  value       = aws_instance.builder_instance.public_ip
  description = "Public IP of the EC2 instance"
}

output "private_key_path" {
  value       = var.private_key_path
  description = "Local path to SSH private key"
}

output "security_group_id" {
  value       = aws_security_group.builder_sg.id
  description = "Security group ID used for the EC2 instance"
}

output "web_dashboard_url" { 
  value = "http://${aws_instance.builder_instance.public_ip}:5001" 
  description = "URL for the Flask web dashboard" 
}

