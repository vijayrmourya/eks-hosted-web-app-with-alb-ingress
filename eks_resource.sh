#!/usr/bin/env bash

# Deploys manifests from the manifests/ directory into a dedicated namespace.
# All resource names prefixed with "ms1-" to avoid conflicts with the learning namespace.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"
NAMESPACE="ms1-webhosting"
REGION="${AWS_REGION:-us-west-2}"

get_my_ip() {
  curl -s https://checkip.amazonaws.com | tr -d '[:space:]'
}

deploy() {
  echo "--- Deploying Milestone Project 1 resources ---"

  MY_IP="$(get_my_ip)/32"
  echo "Your IP: $MY_IP"

  # Namespace, Deployment, Service — static manifests
  kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
  kubectl apply -f "$MANIFESTS_DIR/deployment.yaml"
  kubectl apply -f "$MANIFESTS_DIR/service.yaml"

  # Ingress — substitute __MY_IP__ placeholder with actual IP
  sed "s|__MY_IP__|$MY_IP|" "$MANIFESTS_DIR/ingress.yaml" | kubectl apply -f -

  echo ""
  echo "--- Waiting for pods to be ready ---"
  kubectl wait --for=condition=Ready pods -l app=ms1-web-app -n "$NAMESPACE" --timeout=120s

  echo ""
  echo "--- Waiting for ALB to be provisioned (up to 3 minutes) ---"
  kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
    ingress/ms1-web-app-ingress -n "$NAMESPACE" --timeout=180s

  ALB_URL=$(kubectl get ingress ms1-web-app-ingress -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

  echo ""
  echo "--- Deployment complete ---"
  echo "ALB URL: http://$ALB_URL"
  echo ""
  echo "Waiting ~180s for targets to become healthy, then testing with:"
  echo "  curl -s http://$ALB_URL"
  sleep 180
  echo "Test response:"
  curl -s http://$ALB_URL
  echo ""
  echo "============================================"
}

status() {
  echo "--- Milestone Project 1 Status ---"
  echo ""

  echo "=== Namespace ==="
  kubectl get namespace "$NAMESPACE" 2>/dev/null || echo "Namespace $NAMESPACE not found"
  echo ""

  echo "=== Pods ==="
  kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || echo "No pods found"
  echo ""

  echo "=== Service ==="
  kubectl get svc -n "$NAMESPACE" 2>/dev/null || echo "No services found"
  echo ""

  echo "=== Endpoints ==="
  kubectl get endpointslices -n "$NAMESPACE" 2>/dev/null || echo "No endpoints found"
  echo ""

  echo "=== Ingress ==="
  kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "No ingress found"
  echo ""

  echo "=== ALB (AWS) ==="
  aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ms1`)].{Name:LoadBalancerName,Scheme:Scheme,State:State.Code,DNS:DNSName}' \
    --output table --region "$REGION" 2>/dev/null || echo "Could not query ALBs"
  echo ""

  echo "=== Target Health ==="
  for TG_ARN in $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `k8s-ms1`)].TargetGroupArn' \
    --output text --region "$REGION" 2>/dev/null); do
    aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
      --output table --region "$REGION" 2>/dev/null
  done
}

delete() {
  echo "--- Deleting Milestone Project 1 resources ---"

  # Delete Ingress first — triggers ALB cleanup by the LB controller
  kubectl delete -f "$MANIFESTS_DIR/ingress.yaml" --ignore-not-found
  echo "Waiting 30s for ALB deletion..."
  sleep 30

  kubectl delete -f "$MANIFESTS_DIR/service.yaml" --ignore-not-found
  kubectl delete -f "$MANIFESTS_DIR/deployment.yaml" --ignore-not-found
  kubectl delete -f "$MANIFESTS_DIR/namespace.yaml" --ignore-not-found

  echo ""
  echo "--- Verifying ALB cleanup ---"
  aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ms1`)].LoadBalancerName' \
    --output text --region "$REGION" 2>/dev/null
  echo "If empty, ALB is cleaned up."
  echo "--- Delete complete ---"
}

usage() {
  echo "Usage: $0 {deploy|delete|status}"
  echo ""
  echo "  deploy  - Apply manifests from manifests/ directory"
  echo "  delete  - Remove all K8S resources and wait for ALB cleanup"
  echo "  status  - Show current state of all resources"
  exit 1
}

# Main
case "${1:-}" in
  deploy) deploy ;;
  delete) delete ;;
  status) status ;;
  *)      usage ;;
esac
