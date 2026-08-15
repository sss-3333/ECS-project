# github-oidc.tf
#
# Lets GitHub Actions authenticate to AWS by proving "I am a workflow
# run from this specific repo" via a signed token — no long-lived
# AWS access keys stored in GitHub secrets at all.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # No thumbprint_list needed — AWS validates GitHub's OIDC provider
  # against its own trusted root CA library, not a pinned thumbprint
  # (this changed in July 2023; older tutorials still show one).
}

# Trust policy: only allows this exact GitHub repo (any branch, since
# workflow_dispatch and push both need to work) to assume this role —
# not any GitHub repo in the world.
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"
    # TagSession is required alongside AssumeRoleWithWebIdentity because
    # aws-actions/configure-aws-credentials@v4 attaches session tags
    # (repo, branch, actor, etc.) to every OIDC assume-role call by
    # default — without this, AWS rejects the whole call.
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Scoped to what this project actually needs to touch — ECR, ECS, VPC/
# networking, the ALB, ACM, Route 53, and the specific IAM role/policy
# the ECS module creates. Not AdministratorAccess.
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:PutLifecyclePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::trackance-tfstate-sss3333",
          "arn:aws:s3:::trackance-tfstate-sss3333/*"
        ]
      },
      {
        Sid    = "Infrastructure"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "ecs:*",
          "acm:*",
          "route53:*",
          "logs:*",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListInstanceProfilesForRole",
          "iam:TagRole"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
