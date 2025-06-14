output "db_instances_details" {
  description = "Details for all created RDS instances."
  value = {
    for k, inst in module.db_instances : k => {
      address                         = inst.db_instance_address
      arn                             = inst.db_instance_arn
      availability_zone               = inst.db_instance_availability_zone
      endpoint                        = inst.db_instance_endpoint
      engine                          = inst.db_instance_engine
      engine_version_actual           = inst.db_instance_engine_version_actual
      hosted_zone_id                  = inst.db_instance_hosted_zone_id
      identifier                      = inst.db_instance_identifier
      resource_id                     = inst.db_instance_resource_id
      status                          = inst.db_instance_status
      name                            = inst.db_instance_name
      username                        = inst.db_instance_username # Note: This is sensitive
      port                            = inst.db_instance_port
      subnet_group_id                 = inst.db_subnet_group_id
      subnet_group_arn                = inst.db_subnet_group_arn
      parameter_group_id              = inst.db_parameter_group_id
      parameter_group_arn             = inst.db_parameter_group_arn
      enhanced_monitoring_iam_role_arn = inst.enhanced_monitoring_iam_role_arn
      cloudwatch_log_groups           = inst.db_instance_cloudwatch_log_groups
      master_user_secret_arn          = inst.db_instance_master_user_secret_arn
      secretsmanager_secret_rotation_enabled = inst.db_instance_secretsmanager_secret_rotation_enabled
    }
  }
  sensitive = true # Marking the whole output as sensitive because it contains usernames
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "database_subnet_group_name" {
  description = "The name of the database subnet group"
  value       = module.vpc.database_subnet_group
}

output "security_group_id" {
  description = "The ID of the security group for the RDS instances"
  value       = module.security_group.security_group_id
}