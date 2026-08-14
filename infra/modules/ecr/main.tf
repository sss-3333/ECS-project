# modules/ecr/main.tf

# NOTE: this repository already exists (created manually in Step 3),
# with your tagged image already pushed to it. Rather than let Terraform
# create a second, duplicate repo, this resource is written to match the
# existing one exactly — then imported into Terraform's state (see the
# terraform import command in the README/notes). After import, Terraform
# treats it as "its own" going forward without recreating anything.
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Without this, every rebuild leaves old untagged images sitting in ECR
# forever, slowly costing storage. This automatically cleans up untagged
# images older than the count below, while never touching tagged ones.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 5 exist"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
