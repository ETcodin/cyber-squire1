# --- TERRAFORM OUTPUTS (CD-AWS-AUTOMATION) ---
# Display important information after infrastructure deployment

# --- VPC INFORMATION ---

output "vpc_id" {
  description = "ID of the custom VPC"
  value       = aws_vpc.cd_net_vpc_01.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.cd_net_vpc_01.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.cd_net_pub_01.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.cd_net_prv_01.id
}

# --- NAT INSTANCE INFORMATION ---

output "nat_instance_id" {
  description = "Instance ID of the NAT instance"
  value       = aws_instance.cd_srv_nat_01.id
}

output "nat_public_ip" {
  description = "Public IP of the NAT instance (use for SSH jump host)"
  value       = aws_instance.cd_srv_nat_01.public_ip
}

output "nat_private_ip" {
  description = "Private IP of the NAT instance"
  value       = aws_instance.cd_srv_nat_01.private_ip
}

output "nat_ssh_command" {
  description = "SSH command to connect to NAT instance"
  value       = "ssh -i ~/cyber-squire-ops.pem ec2-user@${aws_instance.cd_srv_nat_01.public_ip}"
}

# --- COREDIRECTIVE_ENGINE INSTANCE INFORMATION ---

output "cdae_instance_id" {
  description = "Instance ID of COREDIRECTIVE_ENGINE"
  value       = aws_instance.cd_srv_cdae_01.id
}

output "cdae_private_ip" {
  description = "Private IP of COREDIRECTIVE_ENGINE (accessible via NAT jump host)"
  value       = aws_instance.cd_srv_cdae_01.private_ip
}

output "cdae_ssh_jump_command" {
  description = "SSH command to connect to CDAE via NAT jump host"
  value       = "ssh -i ~/cyber-squire-ops.pem -J ec2-user@${aws_instance.cd_srv_nat_01.public_ip} ec2-user@${aws_instance.cd_srv_cdae_01.private_ip}"
}

# --- SECURITY GROUP INFORMATION ---

output "nat_security_group_id" {
  description = "Security group ID for NAT instance"
  value       = aws_security_group.cd_sec_nat_01.id
}

output "cdae_security_group_id" {
  description = "Security group ID for COREDIRECTIVE_ENGINE"
  value       = aws_security_group.cd_sec_cdae_01.id
}

# --- CLOUDFLARE TUNNEL ACCESS ---
# n8n dashboard is accessed via Cloudflare Tunnel (no direct port exposure)

output "n8n_access_note" {
  description = "How to access n8n dashboard"
  value       = "n8n dashboard: Access via Cloudflare Tunnel (https://[your-subdomain].[your-domain].com) - No direct port exposure for security"
}

# --- COST ESTIMATE ---

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = <<-EOT
    Cost Breakdown (Monthly):
      - CDAE Instance (${var.cdae_instance_type}):  ~$122
      - NAT Instance (${var.nat_instance_type}):     ~$3.80
      - EBS Volume (${var.cdae_volume_size}GB gp3):  ~$${var.cdae_volume_size * 0.08}
      - Data Transfer (~50GB):      ~$5
      ------------------------------
      Total:                        ~$${122 + 3.80 + (var.cdae_volume_size * 0.08) + 5}

    Savings vs AWS NAT Gateway:   $28/month ($336/year)
  EOT
}

# --- NEXT STEPS ---

output "deployment_next_steps" {
  description = "What to do after Terraform completes"
  value = <<-EOT
    === DEPLOYMENT COMPLETE ===

    1. SSH to NAT instance:
       ${format("ssh -i ~/cyber-squire-ops.pem ec2-user@%s", aws_instance.cd_srv_nat_01.public_ip)}

    2. SSH to CDAE instance (via NAT jump):
       ${format("ssh -i ~/cyber-squire-ops.pem -J ec2-user@%s ec2-user@%s", aws_instance.cd_srv_nat_01.public_ip, aws_instance.cd_srv_cdae_01.private_ip)}

    3. On CDAE instance, complete setup:
       cd /home/ec2-user/COREDIRECTIVE_ENGINE
       git clone [your-repo] .
       ./cdae-init.sh
       cp .env.template .env
       nano .env  # Fill in real credentials
       docker compose up -d
       ./cdae-healthcheck.sh

    4. Configure Cloudflare Tunnel for n8n access
       (See: docs/Technical_Vault.md#cloudflare-tunnel-setup)

    5. Verify NAT instance is routing correctly:
       # From CDAE instance:
       curl -I https://google.com
       # Expected: HTTP 200 (internet access via NAT)

    === DOCUMENTATION ===
    - Architecture: docs/CD_AWS_AUTOMATION.md
    - Operations: docs/PRIVATE_OPERATIONS_MANUAL.md
    - Troubleshooting: docs/ADHD_Runbook.md
  EOT
}

# --- RESOURCE INVENTORY (CD-Standard Naming) ---

output "resource_inventory" {
  description = "All CD-Standard named resources created"
  value = {
    vpc                = aws_vpc.cd_net_vpc_01.id
    internet_gateway   = aws_internet_gateway.cd_net_igw_01.id
    public_subnet      = aws_subnet.cd_net_pub_01.id
    private_subnet     = aws_subnet.cd_net_prv_01.id
    public_route_table = aws_route_table.cd_net_rtb_pub.id
    private_route_table = aws_route_table.cd_net_rtb_prv.id
    nat_instance       = aws_instance.cd_srv_nat_01.id
    cdae_instance      = aws_instance.cd_srv_cdae_01.id
    nat_security_group = aws_security_group.cd_sec_nat_01.id
    cdae_security_group = aws_security_group.cd_sec_cdae_01.id
  }
}

# --- VERIFICATION COMMANDS ---

output "verification_commands" {
  description = "Commands to verify deployment"
  value = <<-EOT
    # Check NAT instance is running
    aws ec2 describe-instances --instance-ids ${aws_instance.cd_srv_nat_01.id} --query 'Reservations[0].Instances[0].State.Name'

    # Check CDAE instance is running
    aws ec2 describe-instances --instance-ids ${aws_instance.cd_srv_cdae_01.id} --query 'Reservations[0].Instances[0].State.Name'

    # Verify NAT routing (SSH to CDAE first)
    ssh -i ~/cyber-squire-ops.pem -J ec2-user@${aws_instance.cd_srv_nat_01.public_ip} ec2-user@${aws_instance.cd_srv_cdae_01.private_ip} 'curl -I https://google.com'

    # Check security group rules
    aws ec2 describe-security-groups --group-ids ${aws_security_group.cd_sec_nat_01.id} ${aws_security_group.cd_sec_cdae_01.id}
  EOT
}
