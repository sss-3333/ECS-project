variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "container_port" {
  type = number
}

variable "ecr_repository_url" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "https_listener_arn" {
  type = string
}
