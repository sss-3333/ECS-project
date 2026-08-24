variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
  default     = "ecs-project-tracker"
}

variable "domain_name" {
  description = "Root domain, already registered in Route 53"
  type        = string
  default     = "trackance.co.uk"
}

variable "subdomain" {
  description = "Subdomain the app is served on"
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Port the app listens on inside the container"
  type        = number
  default     = 3000
}

variable "image_tag" {
  description = "Docker image tag to deploy (commit SHA)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "AZs to spread public subnets across"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}
