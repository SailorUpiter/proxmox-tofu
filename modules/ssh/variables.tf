
# Ssh keys
variable "private_key_file" {
  description = "SSH privte key file"
  type        = string
  default     = "./"
}
variable "public_key_file" {
  description = "SSH public key file"
  type        = string
  default     = "./"
}