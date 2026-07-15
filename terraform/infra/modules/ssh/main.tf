resource "tls_private_key" "vm_ssh_key" {
  algorithm = "ED25519" 
}

# Сохраняем приватный ключ локально
resource "local_sensitive_file" "private_key" {
  content     = tls_private_key.vm_ssh_key.private_key_openssh
  count       = length(var.key_name)         
  filename        = element(var.key_name, count.index) 
  file_permission = "0600"
}

# Сохраняем публичный ключ локально
resource "local_file" "public_key" {
  content  = tls_private_key.vm_ssh_key.public_key_openssh
  count    = length(var.key_name)         
  filename = "${element(var.key_name, count.index)}.pub"
}

