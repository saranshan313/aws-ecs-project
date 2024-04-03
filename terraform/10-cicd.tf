#CodeCommit Repository for ECS App
resource "aws_codecommit_repository" "ecs_app" {
  repository_name = "repo-${local.settings.env}-${local.settings.region}-ecsapp-01"
  description     = "This is the Sample App Repository"
  default_branch  = "main"

  tags = merge(
    local.tags,
    {
      Name = "repo-${local.settings.env}-${local.settings.region}-ecsapp-01"
    }
  )
}

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
      aws_s3_bucket.ecs_codebuild.arn,
      "${aws_s3_bucket.ecs_codebuild.arn}/*",
      aws_s3_bucket.ecs_pipeline.arn,
      "${aws_s3_bucket.ecs_pipeline.arn}/*"
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
  statement {
    effect = "Allow"
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = ["*"]
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

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = local.regions[local.settings.region]
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "repo-${local.settings.env}-${local.settings.region}-app-01"
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = "webapp"
    }


  }

  source {
    type     = "CODECOMMIT"
    location = "https://git-codecommit.${local.settings.region}.amazonaws.com/v1/repos/repo-${local.settings.env}-${local.settings.region}-ecsapp-01"
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

resource "aws_iam_role_policy_attachment" "ecs_codedeploy_permission_policy" {
  role       = aws_iam_role.ecs_codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_role" "ecs_codedeploy" {
  name = "role-${local.settings.env}-${local.settings.region}-ecsdeploy-01"

  assume_role_policy = data.aws_iam_policy_document.ecs_codedeploy_assume_policy.json

  tags = merge(
    local.tags,
    {
      Name = "role-${local.settings.env}-${local.settings.region}-ecsdeploy-01"
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
  service_role_arn       = aws_iam_role.ecs_codedeploy.arn

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
  tags = merge(
    local.tags,
    {
      Name = "deploy-${local.settings.env}-${local.settings.region}-ecs-01"
    }
  )
}

#Code Pipeline for ECS project
resource "aws_codepipeline" "ecs_apps" {
  name     = "pipeline-${local.settings.env}-${local.settings.region}-ecs-01"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.ecs_pipeline.bucket
    type     = "S3"
  }

  stage {
    name = "source-${local.settings.env}-${local.settings.region}-ecs-01"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      run_order        = 1

      configuration = {
        RepositoryName       = "repo-${local.settings.env}-${local.settings.region}-ecsapp-01"
        BranchName           = "main"
        PollForSourceChanges = true
      }
    }
  }

  stage {
    name = "build-${local.settings.env}-${local.settings.region}-ecs-01"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      run_order        = 1

      configuration = {
        ProjectName = "build-${local.settings.env}-${local.settings.region}-ecs-01"
      }
    }
  }

  stage {
    name = "deploy-${local.settings.env}-${local.settings.region}-ecs-01"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["build_output"]
      version         = "1"
      run_order       = 1

      configuration = {
        ApplicationName                = "deploy-${local.settings.env}-${local.settings.region}-ecs-01"
        DeploymentGroupName            = "deploygrp-${local.settings.env}-${local.settings.region}-ecs-01"
        TaskDefinitionTemplatePath     = "imagedefinitions.json"
        TaskDefinitionTemplateArtifact = "build_output"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            = "appspec.yaml"
        #        Image1ArtifactName             = "build_output"
        Image1ContainerName = "webapp"
      }
    }
  }
}

# #Source Code repository type to trigger codepipeline
# resource "aws_codestarconnections_connection" "source_provider" {
#   name          = "sourceconn-${local.settings.env}-${local.settings.region}-ecs-01"
#   provider_type = "GitHub"
# }

#S3 bucket for Code Pipeline
resource "aws_s3_bucket" "ecs_pipeline" {
  bucket = "s3-${local.settings.env}-${local.settings.region}-ecspipeline-01"
}

resource "aws_s3_bucket_public_access_block" "ecs_pipeline" {
  bucket = aws_s3_bucket.ecs_pipeline.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "ecs_pipeline" {
  bucket = aws_s3_bucket.ecs_pipeline.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecs_pipeline" {
  bucket = aws_s3_bucket.ecs_pipeline.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#IAM Role for Code Pipeline
data "aws_iam_policy_document" "pipeline_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "role-${local.settings.env}-${local.settings.region}-ecspipeline-01"
  assume_role_policy = data.aws_iam_policy_document.pipeline_assume_role.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.ecs_pipeline.arn,
      "${aws_s3_bucket.ecs_pipeline.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetApplication",
      "ecs:RegisterTaskDefinition"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}
