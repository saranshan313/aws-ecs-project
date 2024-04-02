#S3 bucket for code build artifacts
resource "aws_s3_bucket" "ecs_codebuild" {
  bucket        = "s3-${local.settings.env}-${local.settings.region}-ecsbuild-01"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "ecs_codebuild" {
  bucket = aws_s3_bucket.ecs_codebuild.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecs_codebuild" {
  bucket = aws_s3_bucket.ecs_codebuild.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "ecs_codebuild_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_codebuild_permission_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.ecs_codebuild.arn}",
      "${aws_s3_bucket.ecs_codebuild.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role" "ecs_codebuild" {
  name = "role-${local.settings.env}-${local.settings.region}-ecsbuild-01"

  assume_role_policy = data.aws_iam_policy_document.ecs_codebuild_assume_policy.json

  tags = merge(
    local.tags,
    {
      Name = "role-${local.settings.env}-${local.settings.region}-ecsbuild-01"
    }
  )
}

resource "aws_iam_role_policy" "ecs_codebuild" {
  role   = aws_iam_role.ecs_codebuild.name
  policy = data.aws_iam_policy_document.ecs_codebuild_permission_policy.json
}

# ECS Code build project
resource "aws_codebuild_project" "ecs_apps" {
  name           = "build-${local.settings.env}-${local.settings.region}-ecs-01"
  description    = "Code Build Project to Create Push Docker image to ECR"
  build_timeout  = 5
  queued_timeout = 5

  service_role = aws_iam_role.ecs_codebuild.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.ecs_codebuild.id
    path     = "ecs-apps"
    name     = "ecs-app.json"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/saranshan313/sample-app.git"
    git_clone_depth = 1
  }

  tags = merge(
    local.tags,
    {
      Name = "build-${local.settings.env}-${local.settings.region}-ecs-01"
    }
  )
}

#Code Deploy for ECS application
data "aws_iam_policy_document" "ecs_codedeploy_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_codedeploy_permission_policy" {
  role   = aws_iam_role.ecs_codebuild.name
  policy = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_role" "ecs_codebuild" {
  name = "role-${local.settings.env}-${local.settings.region}-ecsbuild-01"

  assume_role_policy = data.aws_iam_policy_document.ecs_codebuild_assume_policy.json

  tags = merge(
    local.tags,
    {
      Name = "role-${local.settings.env}-${local.settings.region}-ecsbuild-01"
    }
  )
}

resource "aws_codedeploy_app" "ecs_apps" {
  compute_platform = "ECS"
  name             = "deploy-${local.settings.env}-${local.settings.region}-ecs-01"
}


resource "aws_codedeploy_deployment_group" "ecs_apps" {
  app_name               = aws_codedeploy_app.ecs_apps.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "deploygrp-${local.settings.env}-${local.settings.region}-ecs-01"
  service_role_arn       = aws_iam_role.example.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_app.name
    service_name = aws_ecs_service.ecs_app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.ecs_app_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.ecs_alb_tg_blue.name
      }

      target_group {
        name = aws_lb_target_group.ecs_alb_tg_green.name
      }
    }
  }
}
