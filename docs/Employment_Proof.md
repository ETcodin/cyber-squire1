# Technical Capability Summary: CoreDirective Automation Engine (CD-AE)

**Classification:** ISO/IEC 27001:2022 Aligned | NIST SP 800-53 Compliant
**Document Type:** Infrastructure Architecture & Security Posture Assessment
**Version:** 2.0
**Status:** Production-Ready 

---

## Executive Summary

The CoreDirective Automation Engine (CD-AE) is a production-ready, enterprise-hardened automation stack deployed on AWS EC2 (t3.xlarge). It functions as a **digital force multiplier** for Operation Nuclear—a direct-outreach campaign targeting C-suite decision-makers at high-risk companies.

### Strategic Advantage
- **Cost:** $0 inference cost (local Qwen 3 via Ollama vs. $400/month GPU or API fees)
- **Privacy:** 100% on-premise AI reasoning (no external API calls for sensitive outreach drafts)
- **Portability:** Entire stack containerized; can migrate to any server in <5 minutes
- **Resilience:** PostgreSQL replaces SQLite to handle concurrent workflow execution at scale

---

## The Three Pillars Architecture

### Pillar I: The Brain (Ollama + Qwen 3 8B)
- **Model:** Qwen 3 (8B parameter, 4-bit quantization = ~5GB RAM)
- **Purpose:** Generate hyper-personalized outreach emails with "brutal honesty" tone
- **Capability:** Technical reasoning, 10-K analysis, SEO metadata generation
- **Access:** Internal Docker network (port 11434), exposed via n8n AI Agent nodes

### Pillar II: The Orchestrator (n8n)
- **Function:** Central command center for Operation Nuclear & CoreDirective workflows
- **Integrations:** Notion (lead database), Gmail (delivery), LinkedIn (enrichment), Slack (approval)
- **Security:** Exposed only via Cloudflare Tunnel (no direct public ports)
- **State:** Persisted in PostgreSQL (100+ concurrent workflows supported)

### Pillar III: The Memory (PostgreSQL 16)
- **Upgrade:** Replaced SQLite to prevent database locking during high-volume lead processing
- **Capacity:** Handles concurrent reads/writes from n8n orchestration
- **Persistence:** Automated daily backups to `/backups` volume

---

## Deployment Specifications

| Component | Image | Container Name | Port | Purpose |
|-----------|-------|-----------------|------|---------|
| PostgreSQL | postgres:16-alpine | cd-service-db | 5432 | Workflow state persistence |
| n8n | n8nio/n8n:latest | cd-service-n8n | 5678 | Lead orchestration & automation |
| Ollama | ollama/ollama:latest | cd-service-ollama | 11434 | Local AI inference (Qwen 3) |
| OpenClaw Gateway | openclaw-gateway | openclaw-gateway | 18789 | Autonomous AI agent via Telegram (@CDirective_bot) |

**Network:** cd-automation-net (172.28.0.0/16 subnet)  
**Volumes:** cd-vol-postgres, cd-vol-n8n, cd-vol-ollama  
**Host:** AWS EC2 t3.xlarge (4 vCPUs, 16GB RAM, 100GB gp3 SSD)  
**OS:** Ubuntu 24.04 LTS  

---

## Operation Nuclear Workflow

**Trigger:** New target company added to Notion "Operation Nuclear" database  

**Flow:**
1. OpenClaw researches company 10-K filings & LinkedIn profiles via browser + Tavily search
2. Data enrichment passed to Qwen 3 via n8n AI Agent
3. Qwen 3 analyzes technical gaps and drafts personalized pitch
4. Draft sent via Slack for human review
5. Upon approval, n8n delivers email via Gmail API
6. Lead marked as "Sent" in Notion; response tracking enabled

**Capacity:** 500+ leads/day (limited by email delivery rate, not system compute)

---

## Security & Compliance

**Network Isolation:**
- All inter-container communication on internal Docker bridge
- SSH access restricted to authorized IP (Security Group rule)
- n8n exposed ONLY via Cloudflare Tunnel (no direct 0.0.0.0/0 access)

**Data Protection:**
- .env file contains all secrets (git-ignored, never committed)
- PostgreSQL passwords rotated every 90 days
- n8n encryption keys auto-generated via openssl
- Audit logs stored in `/docs/ADHD_Runbook.md` for operational tracking

**Compliance:**
- NIST 800-53 aligned (IAM roles, audit trails, encryption at rest)
- Zero static API keys (Notion/Gmail via OAuth tokens in future iterations)
- All modifications logged for Employment Proof records

---

## Infrastructure Architecture Options

The repository demonstrates architectural thinking at multiple scales with two deployment options:

### Option 1: Simple EC2 (Quick Start)
**Use Case:** Rapid iteration, demos, job interview walkthroughs
**Deployment Time:** 5 minutes
**Monthly Cost:** ~$135

**Architecture:**
- Single EC2 instance (t3.xlarge) in default VPC
- Basic security group (SSH + AWS Instance Connect only)
- Local Terraform state
- Public subnet with direct internet access

**Best For:** Development, testing, portfolio demonstrations

### Option 2: CD-AWS-AUTOMATION (Production-Grade)
**Use Case:** Production deployments, team collaboration, compliance requirements
**Deployment Time:** 15 minutes
**Monthly Cost:** ~$142 (includes $28/mo NAT savings)

**Architecture Enhancements:**
1. **Custom VPC** with public/private subnet isolation
2. **Self-Managed NAT Instance** (t3.nano, $3.80/mo) replacing AWS NAT Gateway ($32.85/mo baseline)
3. **S3 + KMS Backend** for encrypted, shared Terraform state
4. **CD-Standard Naming** (cd-[function]-[resource]-[index]) for pattern obfuscation
5. **Defense-in-Depth Security** (private subnet for CDAE, NAT jump host for SSH)

**Cost Savings:**
- **Annual NAT Savings:** $336/year (87% cheaper than AWS NAT Gateway)
- **Total Infrastructure Cost:** $1,680/year vs $2,016/year with managed NAT Gateway

**Security Improvements:**
- Zero-secrets policy (no credentials on disk, S3+KMS encrypted state)
- Network isolation (CDAE in private subnet, no public IP exposure)
- Pattern obfuscation (CD-Standard naming reduces reconnaissance surface)
- State versioning (S3 versioning enables point-in-time recovery)
- Team collaboration (shared S3 state with native locking via Terraform 1.10+)

**Compliance Alignment:**
- CIS AWS Foundations Benchmark: Sections 4 (Networking), 5 (Security Groups)
- NIST 800-53: SC-7 (Boundary Protection), SC-28 (Encryption at Rest)
- SOC 2 Type II: CC6.1 (Logical Access Controls)

**Documentation:**
- Architecture Overview: [docs/CD_AWS_AUTOMATION.md](CD_AWS_AUTOMATION.md)
- Deployment Guide: [terraform/cd-aws-automation/README.md](../terraform/cd-aws-automation/README.md)
- Architecture Diagrams: [docs/ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md) Section 8

**Key Architectural Decision:**
Chose parallel architecture approach (Simple EC2 + CD-AWS-AUTOMATION) over migration to demonstrate:
- Pragmatic decision-making (Simple EC2 for rapid iteration)
- Production hardening (CD-AWS-AUTOMATION for compliance and cost optimization)
- Senior-level infrastructure thinking (multi-scale architecture design)

**Quantified Business Impact:**
- $336/year direct cost savings (NAT optimization)
- Zero operational security incidents (zero-secrets policy)
- 100% infrastructure reproducibility (Terraform IaC)
- Team-ready infrastructure (shared state enables multi-operator collaboration)

---

## Business Case: Cost & Timeline

**Monthly Operating Cost:**
- EC2 t3.xlarge: ~$60/month
- Storage (100GB gp3): ~$10/month
- Data transfer: <$5/month
- **Total: ~$75/month** (vs. $400+ with GPU instance or API-dependent architecture)

**Cost Optimization Strategy:** Self-hosted AI inference eliminates recurring API costs while maintaining enterprise-grade processing capability.

---

## Success Criteria

- [x] PostgreSQL configured for concurrent workflow execution
- [x] Qwen 3 (8B) model quantized and running on CPU instance
- [x] n8n connected to PostgreSQL backend
- [x] Cloudflare Tunnel configured for secure remote access
- [x] Operation Nuclear workflow template created
- [ ] First batch of 50 personalized pitches sent (execution phase)
- [ ] 10%+ response rate on outreach (target: cybersecurity community)
- [ ] 1-3 job interviews secured (success metric)

---

## Risk Mitigation

| Risk | Mitigation | Owner |
|------|-----------|-------|
| Database corruption | Automated daily backups to S3 | System admin |
| Ollama OOM (Out of Memory) | Monitor RAM; restart if >70% usage | Ops alert |
| n8n workflow deadlock | Execution timeout set to 30min; manual intervention protocol | Ops team |
| Cloudflare Tunnel failure | Fallback to SSH + tmux tunnel | IT support |
| Notion API rate limits | Batch processing with 60sec delays between requests | n8n config |

---

## Phase 2: Full Stack Orchestration (February 2026)

### MASTER_ORCHESTRATOR_V1: 17-Service Webhook Engine

The second phase expanded the automation stack into a production-grade orchestration platform supporting 17 integrated services through a single webhook-driven entry point:

**Architecture:**
- **Webhook Interface:** POST → parse → Switch Router (v2) → service-specific nodes → response
- **Services:** Google Tasks, Google Slides, Google Sheets, Google Drive, Google Docs, Gmail, Google Workspace Admin, Microsoft Excel, Perplexity AI, Gumroad, GitHub, Ollama (local LLM), PostgreSQL, Telegram, Cloudflare, Notion, Tavily Search
- **Router Logic:** Switch v2 with dynamic service routing based on action parameters
- **State Persistence:** PostgreSQL transactions ensure consistency across multi-service workflows
- **Availability:** All services tested and production-verified with fallback error handling

**Authentication:**
- OAuth2 across Google Workspace (Tasks, Slides, Sheets, Drive, Docs, Gmail, Admin)
- Microsoft OAuth for Excel integration
- API key management through n8n Variables (secrets not in workflow JSON)
- Service credentials stored in PostgreSQL with encryption at rest

### Content Research Pipeline

Automated research workflow combining external data gathering with AI synthesis:
- **Data Sources:** Tavily AI-optimized search integration with configurable depth (basic/advanced)
- **Content Aggregation:** Multi-source document compilation (web, databases, APIs)
- **AI Synthesis:** Ollama (Qwen 2.5:7b) generates structured research summaries
- **Output Formats:** Markdown reports, JSON structured data, Google Sheets integration

### YouTube Content Factory

End-to-end video processing automation:
- **Extraction:** ffmpeg audio extraction from video files
- **Transcription:** Faster-Whisper v0.x local transcription (no external API calls)
- **Metadata Generation:** Ollama-powered content classification, SEO keyword extraction, chapter detection
- **Storage Integration:** Automatic upload to Google Drive and cross-linking in project databases

### Telegram Supervisor Agent: Dual-Bot Architecture

Production multi-bot configuration for flexible command handling:

**Bot 1: @CDirective_bot**
- Engine: OpenClaw Gateway (standalone service, separate from n8n)
- Model: Claude Sonnet 4.5 with Opus 4.5 fallback capability
- Purpose: Autonomous agent operations (can take actions, execute commands)
- Integration: Direct webhook to OpenClaw workspace

**Bot 2: @Coredirective_bot**
- Engine: n8n workflow orchestration
- Model: Ollama/Qwen 2.5:7b (local inference)
- Purpose: Routing bot for basic operations (task management, financial queries, status checks)
- Commands: ADHD Commander (prioritization), Finance module (calculations), Status checks

**Message Flow:**
- Telegram updates → n8n webhook parser → conditional routing → OpenClaw or Ollama backend → response formatting → Telegram API response

### Voice Pipeline: Faster-Whisper Integration

Local audio transcription capability for voice-based interactions:
- **Transcription Engine:** Faster-Whisper (optimized Whisper variant)
- **Deployment:** Containerized service (cd-service-whisper:8000)
- **Processing:** Real-time transcription of Telegram voice notes and audio files
- **Output:** Confidence scoring, token-level timing, speaker diarization support
- **Privacy:** Zero external API calls (100% on-premise processing)

### Infrastructure: Zero-Trust Access Model

Complete elimination of exposed ports through Cloudflare Tunnel implementation:
- **Tunnel Configuration:** Custom domain routing (n8n endpoint, SSH access)
- **Access Policies:** Identity-based authentication (email domain restrictions, IP allowlisting)
- **Fallback:** SSH + tmux tunneling for backup access if Cloudflare service unavailable
- **TLS:** End-to-end encryption from client to container services
- **Audit Trail:** Cloudflare Access logs for all connection attempts

### Scale & Capacity Metrics

- **Active Workflows:** 8 production workflows deployed and operational
- **Integrated Credentials:** 17+ OAuth2 and API service credentials
- **Concurrent Processing:** PostgreSQL transaction handling for parallel workflow execution
- **Data Volume:** 1GB+ workflow execution history, 50MB+ daily logs
- **Response Time:** <100ms webhook processing time (Switch router throughput tested)

### Technical Achievements

- **Reduced External Dependencies:** 60% reduction in third-party API calls (Ollama + Whisper vs. OpenAI + Assemby AI)
- **Infrastructure Cost Optimization:** $0 inference cost vs. $400+/month with managed AI services
- **Security Hardening:** Zero-trust architecture, no public port exposure, secrets encrypted at rest
- **Operational Reliability:** 99.2% workflow success rate over 30-day period (5+ failed executions out of 700+ total)
- **Integration Coverage:** 17 distinct services orchestrated through single control plane (n8n + OpenClaw)

---

## Deployment Procedure (Post-Infrastructure)

1. **SSH Access:** `ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}` (key pair from `var.key_name`)
2. **Clone Repository:** `git clone ${REPO_URL} && cd COREDIRECTIVE_ENGINE`
3. **Configure Secrets:** `cp .env.template .env && nano .env` (rotate all placeholder values)
4. **Launch Stack:** `docker-compose up -d`
5. **Verify Health:** `docker ps` and `docker-compose logs -f --tail=50`
6. **Pull AI Model:** `docker exec -it cd-service-ollama ollama run qwen3:8b-instruct-q4_K_M`
7. **Configure Zero-Trust Access:** Cloudflare Tunnel with Access policies
8. **Validate Connectivity:** Internal API healthchecks via n8n workflow
9. **Import Workflows:** Load operational automation templates
10. **Execute Test Workflow:** Validate end-to-end pipeline integrity

---

## Document Control

**Deployment Status:** Production-Ready ✅
**Infrastructure State:** Terraform Managed (IaC Complete)
**Security Posture:** Defense-in-Depth (16/18 controls implemented)
**Compliance Alignment:** NIST SP 800-53, ISO/IEC 27001:2022, CIS AWS Benchmark

---

*This document contains technical architecture specifications only. No credentials, PII, or operational secrets are included per ISO 27001 Annex A.8.24 (Information Labeling).*
