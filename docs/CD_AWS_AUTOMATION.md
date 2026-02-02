# CD-AWS-AUTOMATION: Production Infrastructure Architecture

## Executive Summary

CD-AWS-AUTOMATION is a production-grade infrastructure pattern designed to eliminate the three most expensive pain points in AWS deployments: excessive NAT Gateway costs, insecure state management, and information leakage through descriptive resource naming.

**The Problem**: Standard AWS architectures rely on Managed NAT Gateways ($32.85/month baseline + data processing fees), store Terraform state locally (creating collaboration barriers and security risks), and use descriptive resource names that expose internal topology to external scanners and audit logs. For a small-to-medium deployment like COREDIRECTIVE_ENGINE, these architectural decisions result in $336/year in unnecessary NAT costs, collaboration friction from local state files, and increased reconnaissance surface for potential attackers.

**The Solution**: CD-AWS-AUTOMATION addresses each pain point with targeted architectural interventions. First, a self-managed NAT instance (t3.nano, ~$3.80/month) replaces the Managed NAT Gateway, delivering identical functionality for 88% less cost. Second, Terraform state is migrated to an S3 backend with KMS encryption and native locking (Terraform 1.10+), enabling team collaboration while eliminating local credential exposure. Third, all resources follow the CD-Standard naming convention (cd-[function]-[resource]-[index]), which obscures topology details while maintaining operational clarity.

**The Result**: This architecture delivers three measurable outcomes:
1. **Cost Optimization**: $28/month NAT savings ($336/year) with zero functionality loss
2. **Security Hardening**: Zero-secrets policy (no credentials on disk), encrypted state at rest, defense-in-depth networking with public/private subnet isolation
3. **Operational Excellence**: Pattern obfuscation reduces reconnaissance surface, CD-Standard naming enables consistent resource grouping and cost tracking, shared S3 state enables team collaboration

CD-AWS-AUTOMATION is designed for production campaigns where cost efficiency, security posture, and team collaboration matter. For quick demos and testing, the Simple EC2 deployment (see [../terraform/simple-ec2/README.md](../terraform/simple-ec2/README.md)) remains the fastest path to deployment. For production workloads requiring compliance, cost optimization, and multi-operator infrastructure, CD-AWS-AUTOMATION is the recommended architecture.

---

## Three Architectural Pillars

### Pillar 1: Cost-Optimized Networking (NAT Decoupling)

**Problem**: AWS NAT Gateways incur a fixed monthly "tax" of $32.85 (730 hours × $0.045/hr) plus per-GB data processing fees ($0.045/GB). For COREDIRECTIVE_ENGINE with moderate outbound traffic (~50GB/month), this totals $37.35/month or $448/year.

**Solution**: Replace the Managed NAT Gateway with a self-managed NAT instance running on a t3.nano ($0.0052/hr). The NAT instance uses IP masquerading (iptables MASQUERADE) to translate private subnet IPs to its public IP, providing identical functionality to the managed service.

**Implementation**:
```terraform
resource "aws_instance" "cd_srv_nat_01" {
  ami                    = data.aws_ami.cd_nat_al2023.id
  instance_type          = "t3.nano"  # $3.80/month
  subnet_id              = aws_subnet.cd_net_pub_01.id
  source_dest_check      = false      # Required for NAT
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables-save > /etc/sysconfig/iptables
  EOF
}
```

**Cost Comparison** (Monthly):

| Service | Hourly Rate | Monthly Cost | Data Processing | Total |
|---------|------------|--------------|-----------------|-------|
| AWS NAT Gateway | $0.045/hr | $32.85 | $0.045/GB × 50GB = $2.25 | **$35.10** |
| Self-Managed NAT (t3.nano) | $0.0052/hr | $3.80 | $0 (included in EC2) | **$3.80** |

**Savings**: $31.30/month, $375.60/year

**Trade-offs**:
- **Availability**: Single-AZ (NAT Gateway supports multi-AZ failover)
- **Throughput**: ~5 Gbps burst (NAT Gateway: up to 100 Gbps)
- **Management**: Manual OS updates (NAT Gateway: fully managed)

**Acceptable For**:
- Single-instance workloads (e.g., COREDIRECTIVE_ENGINE)
- Development/staging environments
- Cost-constrained production deployments with <10 GB/day egress traffic

**Not Recommended For**:
- Multi-AZ production requiring high availability
- High-throughput workloads (>10 Gbps sustained)
- Strict managed-service-only compliance requirements

### Pillar 2: Stateless Security & Zero-Secrets Policy

**Problem**: Local Terraform state files (terraform.tfstate) contain every resource ID, often including plaintext secrets for certain providers. Storing state locally creates three risks:
1. **Credential Exposure**: Accidental git commit exposes entire infrastructure topology and secrets
2. **Collaboration Friction**: Multiple operators can't work on infrastructure simultaneously
3. **State Loss**: No backup/recovery mechanism if local file is corrupted or deleted

**Solution**: Migrate Terraform state to an S3 backend with server-side KMS encryption. Terraform 1.10+ introduces native S3 state locking (using optimistic concurrency with ETags), eliminating the need for a separate DynamoDB table and reducing monthly costs by $0.25.

**Implementation**:

1. **Create KMS Key** (manual, before Terraform):
```bash
aws kms create-key \
  --description "Terraform state encryption for CD-AWS-AUTOMATION" \
  --key-usage ENCRYPT_DECRYPT \
  --origin AWS_KMS
```

2. **Create S3 Bucket** (manual, before Terraform):
```bash
aws s3api create-bucket --bucket cd-str-tfstate-01 --region us-east-1
aws s3api put-bucket-versioning --bucket cd-str-tfstate-01 --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket cd-str-tfstate-01 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/cd-iam-kms-tfstate"
      }
    }]
  }'
```

3. **Configure Backend** (backend.tf):
```terraform
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket         = "cd-str-tfstate-01"
    key            = "prod/cd-aws-automation.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-..."
    use_lockfile   = true  # Terraform 1.10+ native S3 locking
  }
}
```

**Benefits**:
1. **Encryption at Rest**: All state data encrypted with KMS (meets compliance: NIST 800-53 SC-28)
2. **State Locking**: Prevents concurrent modifications (avoids race conditions, corruption)
3. **Versioning**: Point-in-time recovery if state is corrupted
4. **Shared State**: Multiple operators can collaborate on infrastructure
5. **No Local Secrets**: Eliminates risk of accidentally committing state to git

**Cost** (Monthly):
- S3 storage: $0.023/GB × ~0.001 GB (1 MB state) = $0.00002
- S3 requests: $0.005/1,000 × ~100 requests = $0.0005
- KMS key: $1.00 (flat rate)
- **Total**: ~$1.00/month

**Alternative** (Legacy, Terraform <1.10):
- DynamoDB table for locking: +$0.25/month
- Terraform 1.10+ eliminates this cost with native S3 locking

### Pillar 3: Pattern Obfuscation (CD-Standard Naming)

**Problem**: Descriptive resource names (e.g., `prod-database-server`, `staging-nat-gateway`) expose internal topology to:
1. **AWS Cost Explorer**: External auditors can map architecture from cost reports
2. **CloudTrail Logs**: Security scanners identify high-value targets
3. **Resource Tags**: Reconnaissance via AWS Resource Groups API
4. **Error Messages**: Application logs inadvertently leak infrastructure details

**Solution**: Adopt CD-Standard naming convention (cd-[function]-[resource]-[index]) for all infrastructure resources. This provides consistent resource grouping while obscuring topology details.

**CD-Standard Format**:
```
cd-[function]-[resource]-[index]
│   │          │          └─ Numeric index (01, 02, ...)
│   │          └─ Resource type abbreviation
│   └─ Function category
└─ Project prefix (CoreDirective)
```

**Function Categories**:
- `iam`: Identity & Access Management (users, roles, policies)
- `net`: Networking (VPC, subnets, routing)
- `sec`: Security Groups, NACLs
- `srv`: Compute Services (EC2, ECS, Lambda)
- `str`: Storage (S3, EBS, RDS)
- `mon`: Monitoring & Logging (CloudWatch, Flow Logs)

**Examples**:

| Descriptive Name | CD-Standard Name | Purpose |
|-----------------|------------------|---------|
| prod-vpc-main | cd-net-vpc-01 | Custom VPC |
| staging-public-subnet-1a | cd-net-pub-01 | Public subnet |
| prod-nat-gateway | cd-srv-nat-01 | NAT instance |
| db-security-group | cd-sec-cdae-01 | CDAE security group |
| terraform-state-bucket | cd-str-tfstate-01 | Terraform state bucket |
| state-encryption-key | cd-iam-kms-tfstate | KMS key for state |

**Benefits**:
1. **Information Leakage Reduction**: Resource names don't reveal purpose or environment
2. **Consistent Grouping**: All networking resources start with cd-net-*
3. **Cost Tracking**: Filter AWS Cost Explorer by "cd-net-*" to analyze networking costs
4. **Audit Clarity**: CloudTrail logs show structured names, not descriptive labels

**Trade-offs**:
- **Onboarding**: New team members need to learn naming convention
- **Cognitive Load**: Not immediately obvious what cd-srv-nat-01 does (requires documentation)

**Mitigation**:
- Use resource tags for human-readable descriptions (not visible in cost reports)
- Maintain naming registry in [PRIVATE_OPERATIONS_MANUAL.md](./PRIVATE_OPERATIONS_MANUAL.md)
- Add comments in Terraform code explaining resource purpose

---

## High-Level Architecture Diagram

```
                           INTERNET
                               ↓
                   ┌───────────────────────┐
                   │  Internet Gateway     │
                   │  cd-net-igw-01        │
                   └───────────┬───────────┘
                               │
         ┌─────────────────────┴─────────────────────┐
         │  VPC: cd-net-vpc-01 (10.0.0.0/16)         │
         │                                            │
         │  ┌──────────────────────────────────┐    │
         │  │ PUBLIC SUBNET                     │    │
         │  │ cd-net-pub-01 (10.0.10.0/24)      │    │
         │  │                                    │    │
         │  │  ┌──────────────────────────┐     │    │
         │  │  │ NAT Instance              │     │    │
         │  │  │ cd-srv-nat-01 (t3.nano)   │     │    │
         │  │  │ - IP Forwarding Enabled   │     │    │
         │  │  │ - iptables MASQUERADE     │     │    │
         │  │  │ - Public IP: X.X.X.X      │     │    │
         │  │  │ - Monthly Cost: $3.80     │     │    │
         │  │  │ - Savings: $28/mo         │     │    │
         │  │  └──────────────────────────┘     │    │
         │  │         ↑                          │    │
         │  │         │ SSH (port 22)            │    │
         │  │         │ From: Your IP Only       │    │
         │  └─────────┼──────────────────────────┘    │
         │            │                                │
         │            ↓ NAT Routing                    │
         │            │ (iptables MASQUERADE)          │
         │  ┌─────────┴──────────────────────────┐    │
         │  │ PRIVATE SUBNET                      │    │
         │  │ cd-net-prv-01 (10.0.20.0/24)        │    │
         │  │                                      │    │
         │  │  ┌────────────────────────────┐     │    │
         │  │  │ COREDIRECTIVE_ENGINE       │     │    │
         │  │  │ cd-srv-cdae-01 (t3.xlarge) │     │    │
         │  │  │                             │     │    │
         │  │  │ ┌─────────────────────┐    │     │    │
         │  │  │ │ PostgreSQL 16       │    │     │    │
         │  │  │ │ (cd-service-db)     │    │     │    │
         │  │  │ │ RAM: 4GB            │    │     │    │
         │  │  │ └─────────────────────┘    │     │    │
         │  │  │ ┌─────────────────────┐    │     │    │
         │  │  │ │ n8n Orchestrator    │    │     │    │
         │  │  │ │ (cd-service-n8n)    │    │     │    │
         │  │  │ │ RAM: 2GB            │    │     │    │
         │  │  │ │ Access: Cloudflare  │    │     │    │
         │  │  │ │ Tunnel Only         │    │     │    │
         │  │  │ └─────────────────────┘    │     │    │
         │  │  │ ┌─────────────────────┐    │     │    │
         │  │  │ │ Ollama + Qwen 3 8B  │    │     │    │
         │  │  │ │ (cd-service-ollama) │    │     │    │
         │  │  │ │ RAM: 7.5GB          │    │     │    │
         │  │  │ └─────────────────────┘    │     │    │
         │  │  │                             │     │    │
         │  │  │ Private IP: 10.0.20.X      │     │    │
         │  │  │ No Public IP               │     │    │
         │  │  │ Internet: Via NAT          │     │    │
         │  │  └────────────────────────────┘     │    │
         │  └────────────────────────────────────┘    │
         │                                            │
         └────────────────────────────────────────────┘

                  TERRAFORM STATE
                        ↓
      ┌──────────────────────────────────────┐
      │ S3 Bucket: cd-str-tfstate-01         │
      │ - Versioning: Enabled                │
      │ - Encryption: KMS (cd-iam-kms-tfstate)│
      │ - Locking: Native S3 (Terraform 1.10+)│
      │ - Cost: ~$1/month                     │
      └──────────────────────────────────────┘
```

**Traffic Flows**:

1. **Inbound SSH (Operator → NAT)**:
   - Source: Your IP (203.0.113.45/32)
   - Destination: cd-srv-nat-01 (public IP)
   - Port: 22 (SSH)
   - Security Group: cd-sec-nat-01 (allows your IP only)

2. **Inbound SSH (Operator → CDAE via NAT Jump)**:
   - Source: Your IP → NAT → CDAE (10.0.20.X)
   - Port: 22 (SSH)
   - Security Group: cd-sec-cdae-01 (allows NAT security group)

3. **Outbound (CDAE → Internet)**:
   - Source: cd-srv-cdae-01 (10.0.20.X)
   - NAT: cd-srv-nat-01 (translates to public IP via MASQUERADE)
   - Destination: Internet (Docker pulls, package updates, n8n webhooks)
   - Return traffic routed back through NAT

4. **n8n Dashboard Access**:
   - NO direct port exposure (port 5678 not open)
   - Access via Cloudflare Tunnel (encrypted, zero-trust)
   - URL: https://[subdomain].[domain].com

---

## Architecture Comparison: Simple EC2 vs CD-AWS-AUTOMATION

| Feature | Simple EC2 | CD-AWS-AUTOMATION | Advantage |
|---------|-----------|-------------------|-----------|
| **Deployment** | | | |
| Time to Deploy | 5 minutes | 15 minutes | Simple EC2 (faster) |
| Terraform Files | 3 files | 9 files | Simple EC2 (simpler) |
| Configuration Steps | 5 steps | 8 steps | Simple EC2 (fewer steps) |
| **Infrastructure** | | | |
| VPC | Default VPC | Custom VPC | CD-AWS-AUTOMATION (isolated) |
| Subnets | Public only | Public + Private | CD-AWS-AUTOMATION (isolation) |
| NAT | N/A (public subnet) | Self-managed (t3.nano) | CD-AWS-AUTOMATION ($28/mo savings) |
| Internet Gateway | Yes | Yes | Equal |
| Route Tables | 1 (default) | 2 (public, private) | CD-AWS-AUTOMATION (granularity) |
| **Security** | | | |
| Security Groups | 1 basic | 2 CD-Standard | CD-AWS-AUTOMATION (defense-in-depth) |
| Subnet Isolation | None (public) | Private subnet | CD-AWS-AUTOMATION (attack surface) |
| Attack Surface | Medium (public IP) | Low (private IP, NAT jump) | CD-AWS-AUTOMATION |
| EBS Encryption | No | Yes | CD-AWS-AUTOMATION (compliance) |
| **State Management** | | | |
| Terraform State | Local file | S3 + KMS | CD-AWS-AUTOMATION (secure, shared) |
| State Locking | No | Yes (native S3) | CD-AWS-AUTOMATION (prevents corruption) |
| State Versioning | No | Yes (S3 versioning) | CD-AWS-AUTOMATION (recovery) |
| State Encryption | No | Yes (KMS) | CD-AWS-AUTOMATION (compliance) |
| Team Collaboration | No (local state) | Yes (shared S3 state) | CD-AWS-AUTOMATION |
| **Naming & Organization** | | | |
| Resource Naming | Mixed (cd-alpha-*) | CD-Standard (cd-*-*-*) | CD-AWS-AUTOMATION (consistency) |
| Naming Convention | Descriptive | Obfuscated | CD-AWS-AUTOMATION (security) |
| Cost Tracking | Manual | Pattern-based (cd-net-*, cd-srv-*) | CD-AWS-AUTOMATION (granular) |
| **Cost** | | | |
| CDAE Instance (t3.xlarge) | $122/mo | $122/mo | Equal |
| NAT | $0 (public subnet) | $3.80/mo (t3.nano) | Simple EC2 ($3.80/mo cheaper) |
| EBS Volume (100GB) | $8/mo | $8/mo | Equal |
| NAT Gateway (if added later) | N/A | Replaced ($28/mo savings) | CD-AWS-AUTOMATION ($28/mo savings) |
| State Management | $0 (local) | $1/mo (S3 + KMS) | Simple EC2 ($1/mo cheaper) |
| **Total Monthly Cost** | **$130** | **$135** | Simple EC2 ($5/mo cheaper) |
| **Annual Cost** | **$1,560** | **$1,620** | Simple EC2 ($60/year cheaper) |
| **Savings vs NAT Gateway** | N/A | $336/year | CD-AWS-AUTOMATION |
| **Compliance** | | | |
| CIS AWS Benchmark | Minimal | Aligned (Sections 4, 5) | CD-AWS-AUTOMATION |
| NIST 800-53 | Minimal | SC-7, SC-28, AC-4 | CD-AWS-AUTOMATION |
| SOC 2 Type II | Not aligned | CC6.1 (Access Controls) | CD-AWS-AUTOMATION |
| **Best For** | | | |
| Use Case | Demos, testing, interviews | Production, teams, compliance | Context-dependent |
| Team Size | 1 operator | 2+ operators | CD-AWS-AUTOMATION (shared state) |
| Environment | Dev, staging | Staging, prod | CD-AWS-AUTOMATION (hardened) |

**Decision Matrix**:

**Use Simple EC2 When**:
- You need to deploy in <10 minutes for a demo or job interview
- You're the only operator (no team collaboration needed)
- Compliance requirements are minimal
- Cost is extremely constrained (every $5/month matters)
- The deployment is temporary (<30 days)

**Use CD-AWS-AUTOMATION When**:
- You're deploying to production or staging environments
- Multiple team members need to modify infrastructure
- Compliance requirements include encryption at rest, network isolation
- You need audit trails (CloudTrail, VPC Flow Logs) for security
- The deployment is long-lived (>30 days)
- You value architectural best practices and defense-in-depth security

---

## When to Use Which Architecture

### Simple EC2: Quick Start & Demos

**Ideal Scenarios**:
1. **Job Interview Walkthroughs**: Deploying live during technical interview (5-minute setup)
2. **POC/MVP Development**: Rapid iteration on application logic (not infrastructure)
3. **Training & Learning**: Teaching n8n workflows, Ollama integration without infrastructure complexity
4. **Temporary Deployments**: Short-lived campaigns (<30 days), conference demos
5. **Cost-Constrained Personal Projects**: Every dollar matters, no compliance requirements

**Limitations**:
- No subnet isolation (higher attack surface)
- Local Terraform state (no team collaboration)
- Basic security posture (single security group)
- No cost optimization for NAT (if needed later)

**Migration Path**: Deploy with Simple EC2, then migrate to CD-AWS-AUTOMATION when:
- Adding second team member (need shared state)
- Moving to production (need compliance)
- Traffic increases (need NAT Gateway → self-managed NAT savings)

### CD-AWS-AUTOMATION: Production & Teams

**Ideal Scenarios**:
1. **Production Campaigns**: Operation Nuclear (3-month outreach campaign)
2. **Team Deployments**: 2+ operators modifying infrastructure
3. **Compliance Requirements**: SOC 2, HIPAA, PCI-DSS audits
4. **Long-Lived Infrastructure**: >30 days uptime, needs operational rigor
5. **Cost Optimization**: High egress traffic (NAT Gateway savings justify complexity)

**Requirements**:
- 15 minutes for initial deployment
- AWS CLI familiarity (KMS key, S3 bucket creation)
- Understanding of VPC networking (public/private subnets)
- Terraform 1.10+ (native S3 locking)

**ROI Calculation**:
- Setup time: +10 minutes vs Simple EC2
- Monthly cost: +$5/month (NAT instance + S3 state)
- Monthly savings (if replacing NAT Gateway): -$28/month
- **Net benefit**: $23/month savings if you would otherwise use NAT Gateway

---

## Cost Analysis: Detailed Breakdown

### Monthly Cost (CD-AWS-AUTOMATION)

| Resource | Type | Unit Cost | Quantity | Monthly Cost |
|----------|------|-----------|----------|--------------|
| **Compute** | | | | |
| CDAE Instance | t3.xlarge (on-demand) | $0.1664/hr | 730 hrs | $121.47 |
| NAT Instance | t3.nano (on-demand) | $0.0052/hr | 730 hrs | $3.80 |
| **Storage** | | | | |
| EBS (CDAE) | gp3 (100GB) | $0.08/GB | 100 GB | $8.00 |
| EBS (NAT) | gp3 (8GB) | $0.08/GB | 8 GB | $0.64 |
| S3 (State) | Standard | $0.023/GB | ~0.001 GB | $0.00 |
| **Data Transfer** | | | | |
| Outbound | Internet egress | $0.09/GB | 50 GB | $4.50 |
| **Security & State** | | | | |
| KMS Key | Flat rate | $1/month | 1 | $1.00 |
| S3 Requests | PUT/GET | $0.005/1K | ~100 | $0.00 |
| **Total** | | | | **$139.41** |

### Annual Cost

- Monthly: $139.41
- Annual: $139.41 × 12 = **$1,672.92**

### Savings vs Alternatives

**vs AWS NAT Gateway**:
- NAT Gateway baseline: $32.85/mo
- NAT Gateway data processing (50GB): $2.25/mo
- Total NAT Gateway cost: $35.10/mo
- Self-managed NAT cost: $3.80/mo
- **Monthly savings**: $31.30
- **Annual savings**: $375.60

**vs Simple EC2 (with NAT Gateway added later)**:
- Simple EC2: $130/mo
- Add NAT Gateway: +$35.10/mo
- Total: $165.10/mo
- CD-AWS-AUTOMATION: $139.41/mo
- **Monthly savings**: $25.69
- **Annual savings**: $308.28

### Cost Optimization Strategies

**1. Reserved Instances (1-Year Commitment)**:
- CDAE t3.xlarge: $121.47/mo → $73/mo (40% savings)
- NAT t3.nano: $3.80/mo → $2.30/mo (40% savings)
- **Total savings**: $50/month, $600/year

**2. Spot Instances (Dev/Staging Only)**:
- CDAE t3.xlarge: $121.47/mo → $36/mo (70% savings)
- Risk: Instance termination with 2-minute warning
- **Total savings**: $85/month, $1,020/year (dev only)

**3. Right-Sizing**:
- Downgrade CDAE to t3.large for dev: $121.47/mo → $61/mo
- Downgrade NAT to t4g.nano (ARM): $3.80/mo → $3.10/mo
- **Total savings**: $61/month, $732/year (dev only)

**4. Reduce Data Transfer**:
- Enable CloudFront for static assets: Reduce egress by 30%
- Use AWS PrivateLink for service-to-service: Reduce egress by 10%
- **Total savings**: ~$2/month, $24/year

---

## CD-Standard Naming Convention (Public Reference)

### Format

```
cd-[function]-[resource]-[index]
```

### Function Codes

| Code | Category | Example Resources |
|------|----------|-------------------|
| `iam` | Identity & Access Management | Users, roles, policies, KMS keys |
| `net` | Networking | VPC, subnets, route tables, IGW |
| `sec` | Security | Security groups, NACLs |
| `srv` | Compute | EC2, ECS, Lambda |
| `str` | Storage | S3, EBS, RDS |
| `mon` | Monitoring | CloudWatch, Flow Logs |

### Resource Abbreviations

| Abbreviation | Resource Type |
|-------------|---------------|
| `vpc` | Virtual Private Cloud |
| `pub` | Public subnet |
| `prv` | Private subnet |
| `igw` | Internet Gateway |
| `rtb` | Route table |
| `nat` | NAT instance/gateway |
| `sg` | Security group |
| `kms` | KMS encryption key |
| `cdae` | COREDIRECTIVE_ENGINE instance |

### Examples

| CD-Standard Name | Resource Type | Purpose |
|-----------------|---------------|---------|
| cd-net-vpc-01 | VPC | Custom VPC (10.0.0.0/16) |
| cd-net-pub-01 | Subnet | Public subnet (10.0.10.0/24) |
| cd-net-prv-01 | Subnet | Private subnet (10.0.20.0/24) |
| cd-net-igw-01 | Internet Gateway | Internet access for public subnet |
| cd-net-rtb-pub | Route Table | Routes for public subnet |
| cd-net-rtb-prv | Route Table | Routes for private subnet (via NAT) |
| cd-srv-nat-01 | EC2 Instance | Self-managed NAT instance |
| cd-srv-cdae-01 | EC2 Instance | COREDIRECTIVE_ENGINE instance |
| cd-sec-nat-01 | Security Group | NAT instance security group |
| cd-sec-cdae-01 | Security Group | CDAE instance security group |
| cd-str-tfstate-01 | S3 Bucket | Terraform state bucket |
| cd-iam-kms-tfstate | KMS Key | Terraform state encryption key |

### Benefits

1. **Consistent Grouping**: All networking resources start with `cd-net-*`
2. **Cost Tracking**: Filter AWS Cost Explorer by pattern (e.g., `cd-srv-*` for compute costs)
3. **Security Auditing**: Quickly identify security-related resources (`cd-sec-*`)
4. **Information Control**: Names don't reveal environment (dev/staging/prod) or purpose

---

## Next Steps

1. **Deploy Infrastructure**: [../terraform/cd-aws-automation/README.md](../terraform/cd-aws-automation/README.md)
2. **Review Private Operations**: [./PRIVATE_OPERATIONS_MANUAL.md](./PRIVATE_OPERATIONS_MANUAL.md) (local only, git-ignored)
3. **Configure COREDIRECTIVE_ENGINE**: [../COREDIRECTIVE_ENGINE/README.md](../COREDIRECTIVE_ENGINE/README.md)
4. **Set Up Monitoring**: [./Technical_Vault.md#monitoring](./Technical_Vault.md)
5. **Operational Runbook**: [./ADHD_Runbook.md](./ADHD_Runbook.md)

---

## For Job Applications

**Recruiters**: This document demonstrates:
- Senior-level architectural thinking (cost optimization, security hardening)
- Quantified impact ($375/year NAT savings, 88% cost reduction)
- Production-ready infrastructure (compliance-aligned, team-ready)

**Engineers**: Full implementation details:
- Terraform code: [../terraform/cd-aws-automation/](../terraform/cd-aws-automation/)
- Technical deep-dive: [./Technical_Vault.md](./Technical_Vault.md)
- Deployment guide: [../terraform/cd-aws-automation/README.md](../terraform/cd-aws-automation/README.md)

**Hiring Managers**: Business case and ROI:
- [./Employment_Proof.md](./Employment_Proof.md) - Executive summary with cost/security metrics
- [../README.md](../README.md) - Project overview

---

**Last Updated**: 2026-01-30
**Architecture**: CD-AWS-AUTOMATION v1.0
**Author**: Emmanuel Tigoue
**For**: Operation Nuclear Infrastructure
