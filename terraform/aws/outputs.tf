output "rds_instance_endpoint" {
  description = "The connection endpoint for the RDS instance."
  value       = aws_rds_instance.default.endpoint
}

output "rds_instance_port" {
  description = "The connection port for the RDS instance."
  value       = aws_rds_instance.default.port
}

output "rds_instance_name" {
  description = "The name of the RDS instance."
  value       = aws_rds_instance.default.identifier
}

output "rds_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = aws_rds_instance.default.arn
}

output "db_name" {
  description = "The initial database name specified."
  value       = aws_rds_instance.default.db_name
}

output "db_master_username" {
  description = "The master username for the database."
  value       = aws_rds_instance.default.username
}

output "generated_db_password" {
  description = "The randomly generated password for the database master user (if no override was provided)."
  value       = random_password.db_password.result
  sensitive   = true
}

output "db_subnet_group_name_actual" {
  description = "The actual DB subnet group name used (either provided or created)."
  value       = aws_rds_instance.default.db_subnet_group_name
}
