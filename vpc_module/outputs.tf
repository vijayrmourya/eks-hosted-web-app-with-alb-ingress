output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "EKS cluster name derived from project name"
  value       = local.cluster_name
}

output "my_ip_cidr" {
  description = "Your public IP as a /32 CIDR"
  value       = local.my_ip_cidr
}
