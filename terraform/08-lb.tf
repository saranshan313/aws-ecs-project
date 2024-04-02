# Load Balancer Security Group
resource "aws_security_group" "ecs_alb_sg" {
  name        = "secgrp-${local.settings.env}-${local.settings.region}-ecslb-01"
  description = "Security Group for ECS LoadBalancer"
  vpc_id      = data.terraform_remote_state.vpc.outputs.network_vpc_id

  dynamic "ingress" {
    for_each = local.settings.ecs_app_lb_sg_rules
    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      security_groups = []
      cidr_blocks     = ingress.value["cidr_blocks"]
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
      Name = "secgrp-${local.settings.env}-${local.settings.region}-ecslb-01"
  })
}


# ECS Application Load balancer
resource "aws_lb" "ecs_alb" {
  name                             = "alb-${local.settings.env}-${local.settings.region}-ecs-alb-01"
  internal                         = local.settings.ecs_alb_internal
  load_balancer_type               = local.settings.ecs_alb_type
  security_groups                  = [aws_security_group.ecs_alb_sg.id]
  subnets                          = [for k, v in data.terraform_remote_state.vpc.outputs.network_public_subnets : v]
  enable_cross_zone_load_balancing = local.settings.ecs_alb_crosszone_lb
  ip_address_type                  = local.settings.ecs_alb_ip_type

  tags = merge(
    {
      Name = "alb-${local.settings.env}-${local.settings.region}-ecs-alb-01"
    },
    local.tags
  )
}

# Target Groups for ECS Application Load Balancer
resource "aws_lb_target_group" "ecs_alb_tg_blue" {
  name        = "tg-${local.settings.env}-${local.settings.region}-ecs-app-blue-01"
  port        = local.settings.ecs_alb_traffic_port
  protocol    = local.settings.ecs_alb_protocol
  target_type = local.settings.ecs_alb_target_type
  vpc_id      = data.terraform_remote_state.vpc.outputs.network_vpc_id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  tags = merge(
    {
      Name = "tg-${local.settings.env}-${local.settings.region}-ecs-app-blue-01"
    },
    local.tags
  )
}

resource "aws_lb_target_group" "ecs_alb_tg_green" {
  name        = "tg-${local.settings.env}-${local.settings.region}-ecs-app-green-01"
  port        = local.settings.ecs_alb_traffic_port
  protocol    = local.settings.ecs_alb_protocol
  target_type = local.settings.ecs_alb_target_type
  vpc_id      = data.terraform_remote_state.vpc.outputs.network_vpc_id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  tags = merge(
    {
      Name = "tg-${local.settings.env}-${local.settings.region}-ecs-app-green-01"
    },
    local.tags
  )
}

#Listener for ECS Load Balancer
resource "aws_lb_listener" "ecs_app_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_alb_tg.id
  }
  tags = merge(
    {
      Name = "listener-${local.settings.env}-${local.settings.region}-ecs-app-01"
    },
    local.tags
  )
}