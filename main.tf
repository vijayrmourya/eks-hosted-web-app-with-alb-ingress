module "vpc" {
  source = "./vpc_module"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source = "./eks_module"

  project_name    = var.project_name
  cluster_name    = module.vpc.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  private_subnets = module.vpc.private_subnets
  my_ip_cidr      = module.vpc.my_ip_cidr
  region          = var.region

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  tags = {
    Environment = "milestone"
  }
}