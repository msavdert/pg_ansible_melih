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

output "resource_group" {
  description = "Details of the Azure Resource Group used or created."
  value = {
    name     = local.effective_resource_group_name
    location = local.effective_resource_group_location
    id       = var.resource_group_name_override == null || var.resource_group_name_override == "" ? (length(azurerm_resource_group.main) > 0 ? azurerm_resource_group.main[0].id : null) : (length(data.azurerm_resource_group.existing) > 0 ? data.azurerm_resource_group.existing[0].id : null)
  }
}

output "virtual_network" {
  description = "Details of the Azure Virtual Network used or created."
  value = {
    name    = local.effective_vnet_name
    id      = local.effective_vnet_id
    address_space = var.vnet_name_override == null || var.vnet_name_override == "" ? (length(azurerm_virtual_network.main) > 0 ? azurerm_virtual_network.main[0].address_space : null) : (length(data.azurerm_virtual_network.existing) > 0 ? data.azurerm_virtual_network.existing[0].address_space : null)
  }
}

output "db_subnet" {
  description = "Details of the Azure Subnet for PostgreSQL Flexible Servers."
  value = {
    name = var.db_subnet_name
    id   = local.effective_db_subnet_id
    address_prefix = var.vnet_name_override == null || var.vnet_name_override == "" ? (length(azurerm_subnet.db_subnet) > 0 ? azurerm_subnet.db_subnet[0].address_prefixes : null) : (length(data.azurerm_subnet.existing_db_subnet) > 0 ? data.azurerm_subnet.existing_db_subnet[0].address_prefixes : null)
  }
}

output "private_dns_zone_postgresql" {
  description = "Details of the Private DNS Zone for PostgreSQL."
  value = {
    name = azurerm_private_dns_zone.postgresql.name
    id   = azurerm_private_dns_zone.postgresql.id
  }
}

output "key_vault" {
  description = "Details of the Azure Key Vault used or created for password management (if applicable)."
  value = local.effective_key_vault_id != null ? {
    name = var.key_vault_name_override == null || var.key_vault_name_override == "" ? (length(azurerm_key_vault.main) > 0 ? azurerm_key_vault.main[0].name : "NotCreatedOrNotNeeded") : data.azurerm_key_vault.existing[0].name
    id   = local.effective_key_vault_id
    uri  = var.key_vault_name_override == null || var.key_vault_name_override == "" ? (length(azurerm_key_vault.main) > 0 ? azurerm_key_vault.main[0].vault_uri : "NotCreatedOrNotNeeded") : data.azurerm_key_vault.existing[0].vault_uri
  } : "NotUsedOrCreated"
}

output "log_analytics_workspace" {
  description = "Details of the Azure Log Analytics Workspace used or created for diagnostics (if applicable)."
  value = local.effective_log_analytics_workspace_id != null ? {
    name          = var.log_analytics_workspace_name_override == null || var.log_analytics_workspace_name_override == "" ? (length(azurerm_log_analytics_workspace.main) > 0 ? azurerm_log_analytics_workspace.main[0].name : "NotCreatedOrNotNeeded") : data.azurerm_log_analytics_workspace.existing[0].name
    id            = local.effective_log_analytics_workspace_id
    workspace_id  = var.log_analytics_workspace_name_override == null || var.log_analytics_workspace_name_override == "" ? (length(azurerm_log_analytics_workspace.main) > 0 ? azurerm_log_analytics_workspace.main[0].workspace_id : "NotCreatedOrNotNeeded") : data.azurerm_log_analytics_workspace.existing[0].workspace_id
  } : "NotUsedOrCreated"
}

output "postgresql_flexible_server_details" {
  description = "A map of all Azure Database for PostgreSQL Flexible Server instance details."
  value = {
    for k, server in azurerm_postgresql_flexible_server.main : k => {
      id    = server.id
      name  = server.name
      fqdn  = server.fqdn
      administrator_login = server.administrator_login
      version             = server.version
      sku_name            = server.sku_name
      storage_gb          = server.storage_mb / 1024
      location            = server.location
      resource_group_name = server.resource_group_name
      delegated_subnet_id = server.delegated_subnet_id
      private_dns_zone_id = server.private_dns_zone_id
      high_availability   = server.high_availability
      availability_zone   = server.availability_zone
      backup_retention_days = server.backup_retention_days
      geo_redundant_backup_enabled = server.geo_redundant_backup_enabled
      key_vault_secret_details = (
        var.database_instances[k].administrator_password_override == null &&
        var.database_instances[k].manage_password_in_key_vault_if_not_overridden &&
        local.effective_key_vault_id != null &&
        contains(keys(azurerm_key_vault_secret.pg_password_secret), k) ?
        {
          vault_id    = azurerm_key_vault_secret.pg_password_secret[k].key_vault_id
          secret_name = azurerm_key_vault_secret.pg_password_secret[k].name
          secret_id   = azurerm_key_vault_secret.pg_password_secret[k].id
        } :
        "PasswordOverriddenOrNotManagedInKV"
      )
    }
  }
  sensitive = true # Contains FQDNs and admin logins
}

output "postgresql_flexible_server_admin_passwords_in_key_vault" {
  description = "Map of Key Vault Secret IDs for managed admin passwords. Only populated if Key Vault is used."
  value = {
    for k, secret in azurerm_key_vault_secret.pg_password_secret : k => {
      secret_id   = secret.id
      secret_name = secret.name
      server_name = azurerm_postgresql_flexible_server.main[k].name
      key_vault_uri = trimsuffix(secret.id, "/secrets/${secret.name}/${secret.version}")
    }
  }
  sensitive = true
}

output "postgresql_flexible_server_connection_strings_example" {
  description = "Example connection strings for psql (replace password placeholder)."
  value = {
    for k, server in azurerm_postgresql_flexible_server.main : k => "psql \"host=${server.fqdn} port=5432 dbname=<your_db_name_here> user=${server.administrator_login} password='<get_from_keyvault_or_override>' sslmode=require\""
  }
  sensitive = true
}
