variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "awssento"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.31.0.0/16"
}

variable "database_instances" {
  description = "A map of database instance configurations. Each key is a unique name for the instance."
  type = map(object({
    identifier_suffix         = string
    db_name                   = string
    engine_version            = optional(string, "14")
    instance_class            = optional(string, "db.t4g.large")
    allocated_storage         = optional(number, 20)
    max_allocated_storage     = optional(number, 100)
    username                  = optional(string, "pgadmin")
    port                      = optional(number, 5432)
    multi_az                  = optional(bool, false)
    backup_retention_period   = optional(number, 1)
    skip_final_snapshot       = optional(bool, true)
    deletion_protection       = optional(bool, false)

    # Password Management
    password_override                              = optional(string, null) # If set, this password is used, and Secrets Manager is bypassed for this instance.
    manage_master_user_password_if_not_overridden  = optional(bool, true)   # If password_override is null, should Secrets Manager manage it?
    manage_master_user_password_rotation           = optional(bool, true)
    master_user_password_rotate_immediately        = optional(bool, false)
    master_user_password_rotation_schedule_expression = optional(string, "rate(15 days)")

    # Maintenance and Logging
    maintenance_window              = optional(string, "Mon:00:00-Mon:03:00")
    backup_window                   = optional(string, "03:00-06:00")
    enabled_cloudwatch_logs_exports = optional(list(string), ["postgresql", "upgrade"])
    # Note: create_cloudwatch_log_group is a module-level variable, set directly on the module block if needed globally.
    # If you need per-instance control, the module structure would need to change or use separate module calls.
    # For now, assuming global setting for create_cloudwatch_log_group in the module call.

    # Performance Insights & Monitoring
    performance_insights_enabled          = optional(bool, true)
    performance_insights_retention_period = optional(number, 7)
    # Note: create_monitoring_role is a module-level variable. Assuming global setting.
    monitoring_interval                   = optional(number, 60)

    # Database Parameters
    db_parameters = optional(list(object({
      name         = string
      value        = string
      apply_method = optional(string, "pending-reboot")
    })), []) # Default changed to an empty list

    # Parameter Group Control
    create_db_parameter_group       = optional(bool, true)
    parameter_group_name            = optional(string, null)
    parameter_group_use_name_prefix = optional(bool, true)
  }))
  default = {
    "sento" = {
      identifier_suffix = "sento"
      db_name           = "sento"
      # Defaults from the type definition will apply here unless overridden
    },
    "sento-test" = {
      identifier_suffix = "sento-test"
      db_name           = "sentotest"
      # Defaults from the type definition will apply here unless overridden
    }
  }
}

variable "namespace" {
  description = "Namespace to prefix resource names. If empty, no prefix is used."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default = {
    Owner     = "Melih Savdert"
    ManagedBy = "Terraform"
  }
}
