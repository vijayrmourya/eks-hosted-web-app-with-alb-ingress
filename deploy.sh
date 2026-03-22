#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-us-west-2}"

check_prerequisites() {
  local missing=0
  for cmd in terraform aws kubectl curl; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: $cmd is not installed"
      missing=1
    fi
  done

  if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    echo "ERROR: AWS credentials not set. Export these before running:"
    echo '  export AWS_ACCESS_KEY_ID="..."'
    echo '  export AWS_SECRET_ACCESS_KEY="..."'
    echo '  export AWS_SESSION_TOKEN="..."  # if using temporary credentials'
    missing=1
  fi

  if [ "$missing" -eq 1 ]; then
    exit 1
  fi

  echo "Prerequisites OK"
}

up() {
  check_prerequisites

  echo ""
  echo "=== Terraform Init ==="
  terraform -chdir="$SCRIPT_DIR" init

  echo ""
  echo "=== Terraform Plan ==="
  terraform -chdir="$SCRIPT_DIR" plan -out=tfplan

  echo ""
  read -p "Apply the infrastructure changes? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi

  echo ""
  echo "=== Terraform Apply ==="
  terraform -chdir="$SCRIPT_DIR" apply tfplan
  rm -f "$SCRIPT_DIR/tfplan"

  echo ""
  echo "=== Configuring kubectl ==="
  CLUSTER_NAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cluster_name)
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

  echo ""
  echo "=== Verifying cluster access ==="
  kubectl get nodes

  echo ""
  echo "=== Deploying K8S resources ==="
  bash "$SCRIPT_DIR/eks_resource.sh" deploy

  echo ""
  echo "============================================"
  echo "  Milestone Project 1 is deployed!"
  echo "  Run: bash eks_resource.sh status"
  echo "  to see the ALB URL and resource state."
  echo "============================================"
}

down() {
  check_prerequisites

  echo "This will delete ALL resources:"
  echo "  1. K8S resources (Ingress -> ALB cleanup, Service, Deployment)"
  echo "  2. Terraform infrastructure (EKS, VPC, IAM)"
  echo ""

  echo "=== Deleting K8S resources ==="
  bash "$SCRIPT_DIR/eks_resource.sh" delete

  echo ""
  read -p "Destroy ALL infrastructure (VPC, EKS, everything)? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi

  echo ""
  echo "=== Terraform Destroy ==="
  terraform -chdir="$SCRIPT_DIR" destroy -auto-approve

  echo ""
  echo "============================================"
  echo "  Milestone Project 1 fully destroyed."
  echo "============================================"
}

case "${1:-}" in
  up)   up ;;
  down) down ;;
  *)
    echo "Usage: bash deploy.sh {up|down}"
    echo ""
    echo "  up   - Deploy infrastructure + K8S resources"
    echo "  down - Delete K8S resources + destroy infrastructure"
    exit 1
    ;;
esac
