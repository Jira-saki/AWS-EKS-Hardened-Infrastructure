module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = var.cluster_name
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
module "security" {
  source       = "../../modules/security"
  vpc_id       = module.vpc.vpc_id
  cluster_name = var.cluster_name
}

module "observability" {
  source          = "../../modules/observability"
  vpc_id          = module.vpc.vpc_id
  data_subnet_ids = module.vpc.data_subnet_ids
}

module "ecr" {
  source = "../../modules/ecr"
}
