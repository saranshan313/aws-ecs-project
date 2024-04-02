#ECS Cluster
resource "aws_ecs_cluster" "ecs_app" {
  name = "cluster-${local.settings.env}-${local.settings.region}-ecs-01"

  tags = merge(
    local.tags,
    {
      Name = "cluster-${local.settings.env}-${local.settings.region}-ecs-01"
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "ecs_app" {
  cluster_name = aws_ecs_cluster.ecs_app.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

#ECS Task Defintion
resource "aws_ecs_task_definition" "ecs_app" {
  family                   = "task-${local.settings.env}-${local.settings.region}-app-01"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn      = aws_iam_role.ecsTaskExecutionRole.arn
  container_definitions = jsonencode([
    {
      name      = "webapp"
      image     = "httpd:2.4"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          name          = "http"
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])

  #volume {
  #name      = "service-storage"
  # efs_volume_configuration {
  #   file_system_id          = aws_efs_file_system.fs.id
  #   root_directory          = "/opt/data"
  #   transit_encryption      = "ENABLED"
  #   transit_encryption_port = 2999
  #   authorization_config {
  #     access_point_id = aws_efs_access_point.test.id
  #     iam             = "ENABLED"
  #   }
  # }
  #}
  ephemeral_storage {
    size_in_gib = 21
  }
  tags = merge(
    local.tags,
    {
      Name = "task-${local.settings.env}-${local.settings.region}-app-01"
    }
  )
}

#ECS Service Definition
resource "aws_ecs_service" "ecs_app" {
  name                 = "svc-${local.settings.env}-${local.settings.region}-app-01"
  cluster              = aws_ecs_cluster.ecs_app.id
  task_definition      = aws_ecs_task_definition.ecs_app.arn
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true
  propagate_tags       = "TASK_DEFINITION"

  network_configuration {
    subnets          = [for k, v in data.terraform_remote_state.vpc.outputs.network_application_subnets : v]
    security_groups  = [aws_security_group.ecs_app_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_alb_tg_blue.arn
    container_name   = "webapp"
    container_port   = 80
  }

  tags = merge(
    local.tags,
    {
      Name = "svc-${local.settings.env}-${local.settings.region}-app-01"
    }
  )

  depends_on = [
    aws_lb_listener.ecs_app_listener,
    aws_iam_role.ecsTaskExecutionRole,
    aws_db_instance.ecs_rds
  ]
}

resource "aws_security_group" "ecs_app_service" {
  name        = "secgrp-${local.settings.env}-${local.settings.region}-ecs-svc-01"
  description = "Security Group for ECS Service"
  vpc_id      = data.terraform_remote_state.vpc.outputs.network_vpc_id

  dynamic "ingress" {
    for_each = local.settings.ecs_app_service_sg_rules
    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      security_groups = [aws_security_group.ecs_alb_sg.id]
      cidr_blocks     = []
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "secgrp-${local.settings.env}-${local.settings.region}-ecs-svc-01"
  })
}

#ECS Service AutoScaling
resource "aws_appautoscaling_target" "ecs_app_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_app.name}/${aws_ecs_service.ecs_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(
    local.tags,
    {
      Name = "asgtarget-${local.settings.env}-${local.settings.region}-ecs-01"
    }
  )
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "mem-scaling-${local.settings.env}-${local.settings.region}-ecs-01"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_app_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_app_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_app_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-scaling-${local.settings.env}-${local.settings.region}-ecs-01"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_app_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_app_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_app_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 80
  }
}