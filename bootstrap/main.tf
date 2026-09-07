resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubOIDC"
    effect  = "Allow"
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
      values   = ["repo:${var.github_org}*/${var.github_repo}*:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::trackance-tfstate-sss3333",
          "arn:aws:s3:::trackance-tfstate-sss3333/*"
        ]
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:PutImage", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
          "ecr:Describe*", "ecr:List*", "ecr:TagResource", "ecr:UntagResource",
          "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
          "ecr:CreateRepository", "ecr:DeleteRepository"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}"
      },
      {
        Sid    = "EC2Networking"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway"
        ]
        Resource = "*"
      },
      {
        Sid    = "LoadBalancing"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSCreate"
        Effect = "Allow"
        Action = [
          "ecs:Describe*", "ecs:List*",
          "ecs:CreateCluster", "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSManage"
        Effect = "Allow"
        Action = [
          "ecs:Describe*", "ecs:List*",
          "ecs:DeleteCluster", "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
          "ecs:TagResource", "ecs:UntagResource"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:cluster/${var.project_name}-cluster",
          "arn:aws:ecs:${var.aws_region}:*:service/${var.project_name}-cluster/${var.project_name}-service"
        ]
      },
      {
        Sid    = "ACM"
        Effect = "Allow"
        Action = [
          "acm:Describe*", "acm:Get*", "acm:List*",
          "acm:RequestCertificate", "acm:DeleteCertificate",
          "acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53"
        Effect = "Allow"
        Action = [
          "route53:Get*", "route53:List*",
          "route53:ChangeResourceRecordSets"
        ]
        Resource = ["arn:aws:route53:::hostedzone/*", "arn:aws:route53:::change/*"]
      },
      {
        Sid      = "Route53ListZones"
        Effect   = "Allow"
        Action   = ["route53:List*"]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:List*",
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy", "logs:TagResource"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}*"
      },
      {
        Sid      = "LogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:UntagRole",
          "iam:ListRoleTags", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.project_name}-ecs-task-execution-role",
          "arn:aws:iam::*:role/${var.project_name}-github-actions-role"
        ]
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::*:role/${var.project_name}-ecs-task-execution-role"
      },
      {
        Sid    = "IAMOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviderTags"
        ]
        Resource = "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"
      }
    ]
  })
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.project_name
}
