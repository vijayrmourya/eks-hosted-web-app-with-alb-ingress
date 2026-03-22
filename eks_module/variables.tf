variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "my_ip_cidr" {
  description = "Your public IP as /32 CIDR for API server access restriction"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
