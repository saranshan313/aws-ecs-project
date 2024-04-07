# Subnet Group for RDS instance
resource "aws_db_subnet_group" "ecs_rds" {
  name       = "dbsubgrp-${local.settings.env}-${local.settings.region}-ecs-01"
  subnet_ids = [for k, v in data.terraform_remote_state.vpc.outputs.network_database_subnets : v]

  tags = merge(
    local.tags,
    {
      Name = "dbsubgrp-${local.settings.env}-${local.settings.region}-ecs-01"
    }
  )
}

#Security Group for RDS Instance
resource "aws_security_group" "ecs_rds" {
  name        = "secgrp-${local.settings.env}-${local.settings.region}-ecs-rds-01"
  description = "Security Group for ECS RDS"
  vpc_id      = data.terraform_remote_state.vpc.outputs.network_vpc_id

  dynamic "ingress" {
    for_each = local.settings.ecs_rds_sg_rules
    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      security_groups = [aws_security_group.ecs_app_service.id]
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
      Name = "secgrp-${local.settings.env}-${local.settings.region}-ecs-rds-01"
  })
}

#RDS Database for ECS Applications
resource "aws_db_instance" "ecs_rds" {
  db_name             = "ecsapps"
  allocated_storage   = local.settings.ecs_rds.allocated_storage
  storage_type        = local.settings.ecs_rds.storage_type
  engine              = local.settings.ecs_rds.engine
  engine_version      = local.settings.ecs_rds.engine_version
  instance_class      = local.settings.ecs_rds.instance_class
  identifier          = "rds-${local.settings.env}-${local.settings.region}-ecs-01"
  username            = local.settings.ecs_rds.username
  deletion_protection = local.settings.ecs_rds.deletion_protection

  vpc_security_group_ids = [
    aws_security_group.ecs_rds.id
  ]
  db_subnet_group_name = aws_db_subnet_group.ecs_rds.name

  manage_master_user_password = local.settings.ecs_rds.manage_master_user_password
  skip_final_snapshot         = local.settings.ecs_rds.skip_final_snapshot

  multi_az = local.settings.ecs_rds.multi_az

  tags = merge(
    local.tags,
    {
      Name = "rds-${local.settings.env}-${local.settings.region}-ecs-rds-01"
  })
}
