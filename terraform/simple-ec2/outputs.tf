output "engine_public_ip" {
  value = aws_instance.cd_alpha_engine.public_ip
}

output "n8n_url" {
  value = "http://${aws_instance.cd_alpha_engine.public_ip}:5678"
}
