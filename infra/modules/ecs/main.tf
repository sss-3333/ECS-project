# modules/ecs/main.tf

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

# Task-level security group: only accepts traffic from the ALB's
# security group on the container port — not from anywhere else. This
# is the tightened version of the rule you added by hand in ClickOps
# (which allowed the port more broadly).
resource "aws_security_group" "ecs_task" {
  name        = "${var.project_name}-ecs-task-sg"
  description = "Allows inbound traffic from the ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-task-sg"
  }
}

# The execution role is what lets ECS itself pull your image from ECR
# and ship container logs to CloudWatch — it's AWS acting on your
# behalf to start the container, not your app's own permissions.
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = true # needed to pull the image from ECR — no NAT gateway in this setup
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name    = var.project_name
    container_port    = var.container_port
  }

  # Wait for the HTTPS listener to exist before starting the service —
  # avoids a race where ECS registers with a target group that has no
  # working listener yet.
  depends_on = [var.https_listener_arn]
}
