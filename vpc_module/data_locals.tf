data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  cluster_name = "${var.project_name}-cluster"

  my_ip_cidr = "${trimspace(data.http.my_ip.response_body)}/32"

  tags = {
    Environment = "learning"
  }
}