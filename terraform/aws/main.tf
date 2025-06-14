terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  resource_prefix = var.namespace == "" ? "" : "${var.namespace}-"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(
    var.common_tags,
    {
      Project = var.project_name # Project tag is specifically set here as it uses another variable
      Name    = "${local.resource_prefix}${var.project_name}" # Default Name tag, can be overridden by specific resources
    }
  )
}

################################################################################
# RDS Module
################################################################################

module "db_instances" {
  source = "terraform-aws-modules/rds/aws"
  for_each = var.database_instances

  identifier = "${local.resource_prefix}${var.project_name}-${each.value.identifier_suffix}"

  engine                   = "postgres"
  engine_version           = each.value.engine_version # Now taken from each instance's config
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"
  # Deriving major version from the instance-specific engine_version
  family                   = "postgres${regex("^(\\d+)", each.value.engine_version)[0]}" 
  major_engine_version     = regex("^(\\d+)", each.value.engine_version)[0]
  instance_class           = each.value.instance_class

  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage

  db_name  = each.value.db_name
  username = each.value.username
  port     = each.value.port

  # Conditional Password Management
  # If password_override is set, use it directly. Otherwise, let Secrets Manager handle it (if enabled).
  password = each.value.password_override != null ? each.value.password_override : null
  manage_master_user_password = each.value.password_override == null && each.value.manage_master_user_password_if_not_overridden

  # These are only effective if manage_master_user_password is true
  manage_master_user_password_rotation              = each.value.manage_master_user_password_rotation
  master_user_password_rotate_immediately           = each.value.master_user_password_rotate_immediately
  master_user_password_rotation_schedule_expression = each.value.master_user_password_rotation_schedule_expression

  multi_az               = each.value.multi_az
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = each.value.maintenance_window
  backup_window                   = each.value.backup_window
  enabled_cloudwatch_logs_exports = each.value.enabled_cloudwatch_logs_exports
  create_cloudwatch_log_group     = true # Assuming this is a global setting for all instances from this module call

  backup_retention_period = each.value.backup_retention_period
  skip_final_snapshot     = each.value.skip_final_snapshot
  deletion_protection     = each.value.deletion_protection

  performance_insights_enabled          = each.value.performance_insights_enabled
  performance_insights_retention_period = each.value.performance_insights_retention_period
  create_monitoring_role                = true # Assuming this is a global setting
  monitoring_interval                   = each.value.monitoring_interval
  monitoring_role_name                  = "${local.resource_prefix}${var.project_name}-${each.key}-monitoring-role"
  monitoring_role_use_name_prefix       = false # Set to false to use the exact name
  monitoring_role_description           = "Monitoring role for ${each.key} database"

  parameters = each.value.db_parameters

  # Parameter Group Control
  create_db_parameter_group       = each.value.create_db_parameter_group
  # If parameter_group_name is provided, use it. Otherwise, the module generates a name if creating one.
  # If create_db_parameter_group is false, this name should be an existing PG name or null for AWS default.
  parameter_group_name            = each.value.parameter_group_name 

  tags = merge(local.tags, { Name = "${local.resource_prefix}${var.project_name}-${each.value.identifier_suffix}" })
  db_option_group_tags = merge(local.tags, {
    "Sensitive" = "low",
    Name = "${local.resource_prefix}${var.project_name}-${each.value.identifier_suffix}-option-group"
  })
  db_parameter_group_tags = merge(local.tags, {
    "Sensitive" = "low",
    Name = "${local.resource_prefix}${var.project_name}-${each.value.identifier_suffix}-parameter-group"
  })
  cloudwatch_log_group_tags = merge(local.tags, {
    "Sensitive" = "high",
    Name = "${local.resource_prefix}${var.project_name}-${each.value.identifier_suffix}-log-group"
  })
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.resource_prefix}${var.project_name}"
  cidr = var.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.resource_prefix}${var.project_name}"
  description = "${local.resource_prefix}${var.project_name} security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      # Assuming all DB instances use the same port, defined by the default in var.database_instances.
      # For a more dynamic approach with potentially different ports per DB, 
      # you might need to create multiple rules or use a security group per DB.
      # Here, we take the port from the first instance in the map as a representative port,
      # or you can hardcode to 5432 if all instances are guaranteed to use it.
      from_port   = values(var.database_instances)[0].port # Or directly use 5432 if that's standard
      to_port     = values(var.database_instances)[0].port # Or directly use 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}