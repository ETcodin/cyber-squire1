variable "my_ip" {
  description = "Your current public IP for restricted SSH/n8n access"
  type        = string
}

variable "key_name" {
  description = "The name of your existing EC2 Key Pair (e.g., cyber-squire-ops)"
  type        = string
  default     = "cyber-squire-ops"
}
