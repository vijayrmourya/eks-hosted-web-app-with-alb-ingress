# EKS-Hosted Web App with ALB Ingress

Terraform + Kubernetes project that provisions a full AWS stack and deploys a containerized web app accessible via an Application Load Balancer.

## Stack

- **Terraform** — modular IaC (vpc_module, eks_module), version-pinned providers
- **AWS EKS** — managed Kubernetes v1.32, private node group (AL2023, gp3 encrypted EBS)
- **AWS VPC** — 3 AZs, public + private subnets, single NAT Gateway
- **AWS ALB** — provisioned by AWS Load Balancer Controller (Helm) via Ingress
- **IAM / IRSA** — least-privilege pod access, no hardcoded credentials
- **Kubernetes** — Deployment (2 replicas), Service, Ingress, Namespace isolation

## Security Highlights

- Worker nodes in private subnets, NAT Gateway for egress
- Kubernetes API endpoint restricted to your IP only
- IRSA for pod-level AWS permissions (no node-level IAM)
- Encrypted EBS volumes (gp3)
- ALB access restricted to your public IP at deploy time

## Traffic Flow

```
Browser → ALB (public subnet) → Target Group (pod IPs) → Pods (private subnet)
```

ALB uses IP mode via VPC CNI — traffic goes directly to pod IPs, no NodePort hop.

## Project Structure

```
.
├── deploy.sh              # Full lifecycle: up | down
├── eks_resource.sh        # K8s resource management: deploy | delete | status
├── main.tf                # Root: wires vpc_module + eks_module
├── variables.tf           # All inputs with defaults
├── versions.tf            # Provider version constraints
├── vpc_module/            # VPC, subnets, NAT Gateway
├── eks_module/            # EKS cluster, node group, add-ons, LB controller
└── manifests/
    ├── namespace.yaml
    ├── deployment.yaml    # 2 replicas, resource limits, readiness/liveness probes
    ├── service.yaml       # ClusterIP → port 5678
    └── ingress.yaml       # ALB, internet-facing, IP mode
```

## Deploy

### Prerequisites
- AWS CLI with credentials
- Terraform >= 1.10
- kubectl

```bash
export AWS_ACCESS_KEY_ID="<your-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-secret>"
export AWS_SESSION_TOKEN="<your-token>"   # if using temporary credentials

bash deploy.sh up
```

> **Never commit credentials.** The repo includes a `.gitignore` that excludes `.env` and `*.tfvars` — use those files locally if needed.

Terraform initializes, plans (with confirmation prompt), applies, configures kubectl, then deploys all Kubernetes resources. ALB URL is printed at the end.

Expected time: ~15–20 minutes.

## Test

```bash
curl http://<ALB_URL>
# Hello from EKS!

bash eks_resource.sh status   # show pods, services, ingress, and ALB URL
```

## Cleanup

```bash
bash deploy.sh down
```

Deletes Ingress (triggers ALB removal), waits for ALB cleanup, removes remaining K8s resources, then runs `terraform destroy`.

## Manage K8s Resources Independently

```bash
bash eks_resource.sh deploy   # deploy app to existing cluster
bash eks_resource.sh delete   # remove app, keep cluster
bash eks_resource.sh status   # show resource state
```

## Cost

~$0.25/hr while running (EKS control plane + 2× t3.medium + NAT Gateway + ALB).  
Always run `bash deploy.sh down` when not in use.
