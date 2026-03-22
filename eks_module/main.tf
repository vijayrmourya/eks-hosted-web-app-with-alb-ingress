################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = [var.my_ip_cidr]

  enable_irsa = true

  # Allow all TCP between nodes — the default SG only allows ephemeral ports
  # (1025-65535), which blocks application traffic on ports like 80, 443.
  node_security_group_additional_rules = {
    ingress_self_all_tcp = {
      description = "Node to node all TCP"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  }

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
  }

  eks_managed_node_groups = {
    webhosting = {
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        role = "webhosting"
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = var.tags
}

################################################################################
# IRSA: AWS Load Balancer Controller
################################################################################

data "http" "lb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lb_controller" {
  name   = "${var.project_name}-lb-controller"
  policy = data.http.lb_controller_iam_policy.response_body
  tags   = var.tags
}

module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.4"

  name = "${var.project_name}-lb-controller"

  policies = {
    lb_controller = aws_iam_policy.lb_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

################################################################################
# Helm: AWS Load Balancer Controller
################################################################################

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.14.1"
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.region
    vpcId       = var.vpc_id

    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.lb_controller_irsa.arn
      }
    }
  })]

  depends_on = [module.eks]
}


