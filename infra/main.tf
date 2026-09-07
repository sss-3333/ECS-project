module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ECR repository itself is managed in bootstrap/ — rarely torn down,
# same reasoning as the OIDC setup. This just reads its details.
data "aws_ecr_repository" "this" {
  name = var.project_name
}

# Always resolves to whatever was most recently pushed to ECR — no
# manual tag to type or keep in sync, locally or in CI.
data "aws_ecr_image" "latest" {
  repository_name = var.project_name
  most_recent     = true
}

module "acm" {
  source = "./modules/acm"

  domain_name = var.domain_name
  subdomain   = var.subdomain
}

module "alb" {
  source = "./modules/alb"

  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  container_port      = var.container_port
  acm_certificate_arn = module.acm.certificate_arn
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  container_port        = var.container_port
  ecr_repository_url    = data.aws_ecr_repository.this.repository_url
  image_digest          = data.aws_ecr_image.latest.image_digest
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  https_listener_arn    = module.alb.https_listener_arn
}

resource "aws_route53_record" "app" {
  zone_id = module.acm.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
