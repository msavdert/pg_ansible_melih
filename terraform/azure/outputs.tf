output "postgresql_server_id" {
  description = "The ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.default.id
}

output "postgresql_server_name" {
  description = "The FQDN of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.default.fqdn
}

output "postgresql_server_administrator_login" {
  description = "The administrator login name for the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.default.administrator_login
}

output "generated_pg_admin_password" {
  description = "The randomly generated password for the PostgreSQL admin user (if no override was provided)."
  value       = random_password.pg_password.result
  sensitive   = true
}

output "resource_group_name" {
  description = "The name of the resource group where resources are deployed."
  value       = azurerm_resource_group.default.name
}
