# ☁️ MyApp — AWS Cloud Architecture

> **Project:** `myapp` &nbsp;|&nbsp; **Region:** `us-east-1` &nbsp;|&nbsp; **Environment:** `production`
> **IaC:** Terraform &nbsp;|&nbsp; **Tier:** AWS Free Tier Optimized

---

## 📐 High-Level Architecture Overview

```mermaid
flowchart TB
    subgraph INTERNET["🌐 Internet"]
        USER["👤 End Users"]
        ADMIN["🔐 Admin / DevOps"]
    end

    subgraph AWS["☁️ AWS Cloud — us-east-1"]
        subgraph EDGE["Edge Services"]
            R53["🌍 Route 53\nmyapp.com\nwww.myapp.com"]
            APIGW["🔗 API Gateway\nHTTP API\nCORS + Logging"]
        end

        subgraph VPC["🏗️ VPC — 10.0.0.0/16"]
            subgraph PUBLIC_AZ1["📦 Public Subnet — us-east-1a\n10.0.1.0/24"]
                ALB_NODE1["⚖️ ALB Node"]
                WEB1["🖥️ Web Server 1\nt2.micro · Nginx\nAmazon Linux 2023"]
                BASTION["🛡️ Bastion Host\nt2.micro"]
            end

            subgraph PUBLIC_AZ2["📦 Public Subnet — us-east-1b\n10.0.2.0/24"]
                ALB_NODE2["⚖️ ALB Node"]
                WEB2["🖥️ Web Server 2\nt2.micro · Nginx\nAmazon Linux 2023"]
            end

            subgraph PRIVATE_AZ1["🔒 Private Subnet — us-east-1a\n10.0.10.0/24"]
                PRIV_PLACEHOLDER1["Reserved for\nApp Tier Expansion"]
            end

            subgraph PRIVATE_AZ2["🔒 Private Subnet — us-east-1b\n10.0.11.0/24"]
                PRIV_PLACEHOLDER2["Reserved for\nApp Tier Expansion"]
            end

            subgraph DB_AZ1["💾 DB Subnet — us-east-1a\n10.0.20.0/24"]
                DB_PLACEHOLDER1["Reserved for\nRDS / Database"]
            end

            subgraph DB_AZ2["💾 DB Subnet — us-east-1b\n10.0.21.0/24"]
                DB_PLACEHOLDER2["Reserved for\nRDS / Database"]
            end

            IGW["🌐 Internet\nGateway"]
        end

        CW["📊 CloudWatch\nAPI GW Logs"]
    end

    USER -- "HTTP :80" --> R53
    R53 -- "Alias Record" --> ALB_NODE1 & ALB_NODE2
    USER -- "API Calls" --> APIGW
    APIGW -- "VPC Link" --> ALB_NODE1 & ALB_NODE2
    ADMIN -- "SSH :22" --> BASTION
    BASTION -- "SSH :22" --> WEB1
    BASTION -- "SSH :22" --> WEB2
    ALB_NODE1 -- ":80 Health Check" --> WEB1
    ALB_NODE2 -- ":80 Health Check" --> WEB2
    IGW --- ALB_NODE1 & ALB_NODE2
    IGW --- WEB1 & WEB2
    IGW --- BASTION
    APIGW -- "Access Logs" --> CW

    style AWS fill:#0f172a,stroke:#334155,color:#f8fafc
    style VPC fill:#1e1b4b,stroke:#6366f1,color:#e0e7ff
    style INTERNET fill:#0c4a6e,stroke:#38bdf8,color:#e0f2fe
    style EDGE fill:#172554,stroke:#3b82f6,color:#bfdbfe
    style PUBLIC_AZ1 fill:#064e3b,stroke:#10b981,color:#d1fae5
    style PUBLIC_AZ2 fill:#064e3b,stroke:#10b981,color:#d1fae5
    style PRIVATE_AZ1 fill:#422006,stroke:#f59e0b,color:#fef3c7
    style PRIVATE_AZ2 fill:#422006,stroke:#f59e0b,color:#fef3c7
    style DB_AZ1 fill:#4c1d95,stroke:#8b5cf6,color:#ede9fe
    style DB_AZ2 fill:#4c1d95,stroke:#8b5cf6,color:#ede9fe
```

---

## 🔄 Request Traffic Flow

```mermaid
sequenceDiagram
    participant User as 👤 End User
    participant DNS as 🌍 Route 53
    participant ALB as ⚖️ ALB (Port 80)
    participant TG as 🎯 Target Group
    participant Web as 🖥️ Nginx (Web Server)

    User->>DNS: GET myapp.com
    DNS-->>User: Resolve → ALB DNS (Alias A Record)
    User->>ALB: HTTP Request :80
    ALB->>TG: Health Check /health
    TG-->>ALB: 200 OK
    ALB->>Web: Forward to healthy target :80
    Web-->>ALB: HTML Response (Dashboard)
    ALB-->>User: HTTP 200 + Dashboard Page

    Note over ALB,Web: Round-robin across AZs<br/>2 targets: us-east-1a, us-east-1b
```

### API Gateway Flow

```mermaid
sequenceDiagram
    participant Client as 🔗 API Client
    participant APIGW as 🔗 API Gateway (HTTP)
    participant VPCLink as 🔌 VPC Link
    participant ALB as ⚖️ ALB
    participant Web as 🖥️ Web Server
    participant CW as 📊 CloudWatch

    Client->>APIGW: API Request (ANY method)
    APIGW->>APIGW: CORS Validation + Throttle Check
    APIGW->>CW: Log (requestId, IP, method, status)
    APIGW->>VPCLink: HTTP_PROXY Integration
    VPCLink->>ALB: Forward via private connection
    ALB->>Web: Route to target
    Web-->>ALB: Response
    ALB-->>VPCLink: Response
    VPCLink-->>APIGW: Response
    APIGW-->>Client: Response + X-Request-ID header

    Note over APIGW: Rate Limit: 2000 req/s<br/>Burst: 5000 req/s
```

---

## 🔐 Security Architecture

```mermaid
flowchart LR
    subgraph SG_LAYERS["Security Group Architecture"]
        subgraph SG_ALB["🛡️ SG: ALB"]
            ALB_IN["✅ Inbound:\n• HTTP :80 from 0.0.0.0/0\n• HTTPS :443 from 0.0.0.0/0"]
            ALB_OUT["✅ Outbound:\n• All traffic (reach targets)"]
        end

        subgraph SG_WEB["🛡️ SG: Web Server"]
            WEB_IN["✅ Inbound:\n• HTTP :80 from 0.0.0.0/0\n• SSH :22 from Bastion SG only"]
            WEB_OUT["✅ Outbound:\n• All traffic (updates)"]
        end

        subgraph SG_BASTION["🛡️ SG: Bastion"]
            BAST_IN["✅ Inbound:\n• SSH :22 from Admin IP"]
            BAST_OUT["✅ Outbound:\n• All traffic"]
        end
    end

    ALB_OUT --> WEB_IN
    BAST_OUT --> WEB_IN

    style SG_LAYERS fill:#0f172a,stroke:#475569,color:#f8fafc
    style SG_ALB fill:#1e3a5f,stroke:#3b82f6,color:#bfdbfe
    style SG_WEB fill:#1a3320,stroke:#22c55e,color:#bbf7d0
    style SG_BASTION fill:#3b1a1a,stroke:#ef4444,color:#fecaca
```

### Network ACL — Private Subnets

```mermaid
flowchart LR
    subgraph NACL["🔒 NACL — Private Subnets (Stateless)"]
        subgraph INBOUND["⬇️ Inbound Rules"]
            R100["Rule 100: Allow TCP :80\nfrom VPC CIDR"]
            R110["Rule 110: Allow TCP :22\nfrom VPC CIDR"]
            R900["Rule 900: Allow TCP :1024-65535\nfrom 0.0.0.0/0\n(Return Traffic)"]
        end

        subgraph OUTBOUND["⬆️ Outbound Rules"]
            E100["Rule 100: Allow ALL\nto 0.0.0.0/0"]
        end
    end

    style NACL fill:#1c1917,stroke:#a8a29e,color:#fafaf9
    style INBOUND fill:#1a2332,stroke:#60a5fa,color:#dbeafe
    style OUTBOUND fill:#1a2e1a,stroke:#4ade80,color:#dcfce7
```

---

## 🧩 Terraform Module Dependency Graph

```mermaid
flowchart TD
    ROOT["🏠 Root Module\nmain.tf"]

    R53_ZONE["🌍 Route 53 Zone\naws_route53_zone.main"]

    VPC["📦 modules/vpc\n• VPC\n• 6 Subnets (2 pub + 2 priv + 2 db)\n• Internet Gateway\n• Route Tables + Associations"]

    SEC["🔐 modules/security\n• 3 Security Groups (ALB, Web, Bastion)\n• NACL for private subnets"]

    COMPUTE["🖥️ modules/compute\n• 2 Web Server EC2 (t2.micro)\n• 1 Bastion EC2 (t2.micro)\n• SSH Key Pair\n• Amazon Linux 2023 AMI"]

    LB["⚖️ modules/load_balancer\n• Application Load Balancer\n• Target Group + Health Check\n• HTTP Listener :80\n• /api/* Routing Rule"]

    DNS["🌐 modules/dns\n• A Record: myapp.com → ALB\n• A Record: www.myapp.com → ALB"]

    APIGW["🔗 modules/api_gateway\n• HTTP API Gateway\n• VPC Link → ALB\n• CloudWatch Log Group\n• CORS + Throttling"]

    ROOT --> R53_ZONE
    ROOT --> VPC
    ROOT --> SEC
    ROOT --> COMPUTE
    ROOT --> LB
    ROOT --> DNS
    ROOT --> APIGW

    VPC -- "vpc_id" --> SEC
    VPC -- "subnet_ids" --> SEC
    VPC -- "private_subnet_ids\npublic_subnet_ids" --> COMPUTE
    VPC -- "public_subnet_ids\nvpc_id" --> LB
    VPC -- "public_subnet_ids" --> APIGW

    SEC -- "webserver_sg_id\nbastion_sg_id" --> COMPUTE
    SEC -- "alb_sg_id" --> LB
    SEC -- "alb_sg_id" --> APIGW

    COMPUTE -- "webserver_instance_ids" --> LB
    LB -- "alb_dns_name\nalb_zone_id" --> DNS
    LB -- "http_listener_arn" --> APIGW
    R53_ZONE -- "zone_id" --> DNS

    style ROOT fill:#4c1d95,stroke:#8b5cf6,color:#f5f3ff
    style VPC fill:#1e3a5f,stroke:#3b82f6,color:#bfdbfe
    style SEC fill:#3b1a1a,stroke:#ef4444,color:#fecaca
    style COMPUTE fill:#1a3320,stroke:#22c55e,color:#bbf7d0
    style LB fill:#422006,stroke:#f59e0b,color:#fef3c7
    style DNS fill:#0c4a6e,stroke:#38bdf8,color:#e0f2fe
    style APIGW fill:#4a1942,stroke:#d946ef,color:#fae8ff
    style R53_ZONE fill:#0c4a6e,stroke:#38bdf8,color:#e0f2fe
```

---

## 🏗️ Network Topology Detail

```mermaid
flowchart TB
    subgraph VPC["🏗️ VPC: 10.0.0.0/16"]
        direction TB
        IGW["🌐 Internet Gateway"]

        subgraph AZ1["Availability Zone — us-east-1a"]
            direction TB
            PUB1["📦 Public Subnet\n10.0.1.0/24\n─────────────\n• ALB Node\n• Web Server 1 (10.0.1.x)\n• Bastion Host (10.0.1.x)"]
            PRIV1["🔒 Private Subnet\n10.0.10.0/24\n─────────────\nReserved (App Tier)"]
            DB1["💾 DB Subnet\n10.0.20.0/24\n─────────────\nReserved (Database)"]
        end

        subgraph AZ2["Availability Zone — us-east-1b"]
            direction TB
            PUB2["📦 Public Subnet\n10.0.2.0/24\n─────────────\n• ALB Node\n• Web Server 2 (10.0.2.x)"]
            PRIV2["🔒 Private Subnet\n10.0.11.0/24\n─────────────\nReserved (App Tier)"]
            DB2["💾 DB Subnet\n10.0.21.0/24\n─────────────\nReserved (Database)"]
        end

        subgraph ROUTING["🗺️ Route Tables"]
            PUB_RT["Public RT\n0.0.0.0/0 → IGW"]
            PRIV_RT1["Private RT (AZ1)\nLocal only (no NAT)"]
            PRIV_RT2["Private RT (AZ2)\nLocal only (no NAT)"]
        end
    end

    IGW --> PUB_RT
    PUB_RT --> PUB1 & PUB2
    PRIV_RT1 --> PRIV1 & DB1
    PRIV_RT2 --> PRIV2 & DB2

    style VPC fill:#1e1b4b,stroke:#6366f1,color:#e0e7ff
    style AZ1 fill:#0f2027,stroke:#2dd4bf,color:#ccfbf1
    style AZ2 fill:#0f2027,stroke:#2dd4bf,color:#ccfbf1
    style ROUTING fill:#1c1917,stroke:#a8a29e,color:#fafaf9
```

---

## 📋 Resource Inventory

### Compute Resources

| Resource | Type | Spec | Subnet | AZ | Free Tier |
|----------|------|------|--------|-----|-----------|
| Web Server 1 | `aws_instance` | t2.micro · 10 GB gp2 · Encrypted | Public (10.0.1.0/24) | us-east-1a | ✅ 750 hrs/mo |
| Web Server 2 | `aws_instance` | t2.micro · 10 GB gp2 · Encrypted | Public (10.0.2.0/24) | us-east-1b | ✅ 750 hrs/mo |
| Bastion Host | `aws_instance` | t2.micro · 8 GB gp2 · Encrypted | Public (10.0.1.0/24) | us-east-1a | ✅ 750 hrs/mo |

### Networking Resources

| Resource | Type | Details |
|----------|------|---------|
| VPC | `aws_vpc` | CIDR: 10.0.0.0/16 · DNS Hostnames: Enabled |
| Internet Gateway | `aws_internet_gateway` | Attached to VPC |
| Public Subnets (×2) | `aws_subnet` | 10.0.1.0/24, 10.0.2.0/24 · Auto-assign Public IP |
| Private Subnets (×2) | `aws_subnet` | 10.0.10.0/24, 10.0.11.0/24 · No internet |
| DB Subnets (×2) | `aws_subnet` | 10.0.20.0/24, 10.0.21.0/24 · Isolated |
| ALB | `aws_lb` | Internet-facing · HTTP/2 · 2 AZs |
| Target Group | `aws_lb_target_group` | Health check: /health · Interval: 30s |
| API Gateway | `aws_apigatewayv2_api` | HTTP API · VPC Link to ALB |

### DNS Resources

| Resource | Type | Target |
|----------|------|--------|
| Route 53 Zone | `aws_route53_zone` | myapp.com |
| A Record (apex) | `aws_route53_record` | myapp.com → ALB (Alias) |
| A Record (www) | `aws_route53_record` | www.myapp.com → ALB (Alias) |

### Security Resources

| Resource | Inbound | Outbound |
|----------|---------|----------|
| ALB SG | HTTP :80, HTTPS :443 from 0.0.0.0/0 | All |
| Web Server SG | HTTP :80 from 0.0.0.0/0, SSH :22 from Bastion SG | All |
| Bastion SG | SSH :22 from Admin IP | All |
| Private NACL | TCP :80/:22 from VPC, Ephemeral from 0.0.0.0/0 | All |

---

## 🔑 SSH Access Path

```mermaid
flowchart LR
    ADMIN["🔐 Admin\n(Your Machine)"]
    BASTION["🛡️ Bastion Host\nPublic Subnet\nus-east-1a"]
    WEB1["🖥️ Web Server 1\nus-east-1a"]
    WEB2["🖥️ Web Server 2\nus-east-1b"]

    ADMIN -- "ssh -i ~/.ssh/id_rsa\nec2-user@bastion-ip\n(Port 22)" --> BASTION
    BASTION -- "ssh ec2-user@private-ip\n(Port 22 · Bastion SG)" --> WEB1
    BASTION -- "ssh ec2-user@private-ip\n(Port 22 · Bastion SG)" --> WEB2

    style ADMIN fill:#4c1d95,stroke:#8b5cf6,color:#f5f3ff
    style BASTION fill:#7f1d1d,stroke:#ef4444,color:#fecaca
    style WEB1 fill:#1a3320,stroke:#22c55e,color:#bbf7d0
    style WEB2 fill:#1a3320,stroke:#22c55e,color:#bbf7d0
```

---

## 💰 Free Tier Cost Summary

| Service | Free Tier Allowance | Usage in Architecture | Status |
|---------|--------------------|-----------------------|--------|
| EC2 (t2.micro) | 750 hrs/month × 12 mo | 3 instances (shared 750 hrs) | ⚠️ Monitor hours |
| EBS (gp2) | 30 GB/month | 28 GB (10+10+8) | ✅ Under limit |
| ALB | 750 hrs + 15 LCUs/mo × 12 mo | 1 ALB | ✅ Within limits |
| Route 53 | — | 1 Hosted Zone ($0.50/mo) | 💲 Paid |
| API Gateway (HTTP) | 1M calls/month × 12 mo | 1 HTTP API | ✅ Within limits |
| CloudWatch Logs | 5 GB ingest + 5 GB storage | API GW logs (30-day retention) | ✅ Within limits |
| Data Transfer | 1 GB out/month | Minimal | ✅ Within limits |

> [!WARNING]
> **Route 53 Hosted Zone** costs **$0.50/month** regardless of usage. Destroy after demo to stop billing.

> [!NOTE]
> **NAT Gateway** has been intentionally removed to stay within free tier. Private/DB subnets have **no internet access**. Web servers are deployed in **public subnets** as a cost-saving measure.

---

## 📂 Terraform Module Structure

```
my-app/
├── scripts/
│   └── user_data.sh              # Standalone reference of bootstrap script
├── terraform/
│   ├── main.tf                   # Root — wires all modules together
│   ├── variables.tf              # Input variables with defaults
│   ├── outputs.tf                # Stack outputs (IPs, DNS, SSH cmd)
│   ├── provider.tf               # AWS provider + default tags
│   ├── versions.tf               # Terraform + provider version locks
│   └── modules/
│       ├── vpc/                  # VPC, 6 subnets, IGW, route tables
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security/             # 3 Security Groups + NACL
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── compute/              # 2 Web Servers + Bastion + Key Pair
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── load_balancer/        # ALB + Target Group + Listener
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── dns/                  # Route 53 A Records (apex + www)
│       │   ├── main.tf
│       │   └── variables.tf
│       └── api_gateway/          # HTTP API GW + VPC Link + CloudWatch
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── terraform.tfstate
```

---

## 🔮 Future Expansion Paths

```mermaid
flowchart TD
    CURRENT["🏠 Current Architecture"]

    HTTPS["🔒 HTTPS/TLS\n• ACM Certificate\n• HTTPS Listener :443\n• HTTP → HTTPS Redirect"]
    NAT["🌐 NAT Gateway\n• Enable private subnet\n internet access\n• Move web servers to\n private subnets"]
    RDS["💾 RDS Database\n• Deploy in DB subnets\n• Multi-AZ for HA\n• DB Security Group"]
    ASG["📈 Auto Scaling Group\n• Launch Template\n• Scaling Policies\n• Replace static EC2s"]
    WAF["🛡️ AWS WAF\n• Attach to ALB\n• Rate limiting\n• SQL injection protection"]
    MONITORING["📊 Enhanced Monitoring\n• CloudWatch Alarms\n• SNS Notifications\n• Route 53 Health Checks"]

    CURRENT --> HTTPS
    CURRENT --> NAT
    CURRENT --> RDS
    CURRENT --> ASG
    CURRENT --> WAF
    CURRENT --> MONITORING

    style CURRENT fill:#4c1d95,stroke:#8b5cf6,color:#f5f3ff
    style HTTPS fill:#1e3a5f,stroke:#3b82f6,color:#bfdbfe
    style NAT fill:#1a3320,stroke:#22c55e,color:#bbf7d0
    style RDS fill:#422006,stroke:#f59e0b,color:#fef3c7
    style ASG fill:#3b1a1a,stroke:#ef4444,color:#fecaca
    style WAF fill:#4a1942,stroke:#d946ef,color:#fae8ff
    style MONITORING fill:#0c4a6e,stroke:#38bdf8,color:#e0f2fe
```

---

<div align="center">

*Architecture managed by **Terraform** · Diagrams auto-generated from IaC analysis*

</div>
