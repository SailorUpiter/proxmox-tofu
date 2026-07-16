output "public_key" {
  description = "The public SSH key"
  value       = tls_private_key.vm_ssh_key.public_key_openssh
}

output "private_key" {
  description = "The private SSH key"
  value       = tls_private_key.vm_ssh_key.private_key_openssh
  sensitive   = true
}