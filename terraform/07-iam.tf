resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "role-${local.settings.env}-${local.settings.region}-ecstask-01"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = merge(
    local.tags,
    {
      Name = "role-${local.settings.env}-${local.settings.region}-ecstask-01"
  })
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_policy" "ecsTaskExecutionRole_policy" {
  name        = "policy-${local.settings.env}-${local.settings.region}-ecstask-01"
  path        = "/"
  description = "Allow ECS task to access the Secrets"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.ecs_rds.arn
      },
    ]
  })
}

