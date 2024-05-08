#Image repository for ECS application
resource "aws_ecr_repository" "ecs_app" {
  name = "repo-${local.settings.env}-${local.settings.region}-ecsapp-01"

  image_scanning_configuration {
    scan_on_push = local.settings.ecr_ecs.scan_on_push
  }

  tags = merge(
    local.tags,
    {
      Name = "repo-${local.settings.env}-${local.settings.region}-ecsapp-01"
    }
  )
}
