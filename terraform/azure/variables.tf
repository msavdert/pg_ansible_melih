variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Name of the project, used for naming resources."
  type        = string
  default     = "azurepg"
}

variable "namespace" {
  description = "Namespace to prefix resource names. If empty, no prefix is used."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {
    TerraformManaged = "true"
    Project          = "azurepg" # Default, can be overridden by project_name
  }
}

variable "resource_group_name_override" {
  description = "Optional: Name of an existing resource group. If null or empty, a new one will be created using project_name and namespace."
  type        = string
  default     = null
}

variable "vnet_name_override" {
  description = "Optional: Name of an existing VNet. If null or empty, a new one will be created."
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "db_subnet_name" {
  description = "Name of the subnet for PostgreSQL servers."
  type        = string
  default     = "PostgreSqlFlexibleServerSubnet" # Name must be specific for delegation
}

variable "db_subnet_address_prefix" {
  description = "Address prefix for the PostgreSQL subnet. Must be within VNet address space."
  type        = string
  default     = "10.10.1.0/24"
}

variable "key_vault_name_override" {
  description = "Optional: Name of an existing Key Vault. If null or empty and password management is enabled, a new one will be created."
  type        = string
  default     = null
}

variable "key_vault_sku_name" {
  description = "SKU name for the Key Vault if created."
  type        = string
  default     = "standard" # or "premium"
}

variable "log_analytics_workspace_name_override" {
  description = "Optional: Name of an existing Log Analytics Workspace. If null or empty and logging is enabled, a new one will be created."
  type        = string
  default     = null
}

variable "log_analytics_workspace_sku" {
  description = "SKU for the Log Analytics Workspace if created."
  type        = string
  default     = "PerGB2018"
}

variable "private_dns_zone_name_for_postgresql" {
  description = "Name of the private DNS zone for PostgreSQL Flexible Server. E.g., 'privatelink.postgres.database.azure.com'. This is typically fixed for Azure public cloud."
  type        = string
  default     = "privatelink.postgres.database.azure.com"
}

variable "database_instances" {
  description = "A map of Azure Database for PostgreSQL Flexible Server configurations."
  type = map(object({
    name_suffix                                   = string # Unique suffix for the server name, e.g., "prod", "dev01"
    version                                       = optional(string, "15") # e.g., "13", "14", "15", "16"
    sku_name                                      = string # e.g., "GP_Standard_D2s_v3", "MO_Standard_E4s_v3". See Azure docs for full list.
    storage_gb                                    = number # Storage in GB, e.g., 32, 128, 256
    administrator_login                           = optional(string, "pgadminuser")
    administrator_password_override               = optional(string, null) # Set to a specific password to override Key Vault management for this instance.
    manage_password_in_key_vault_if_not_overridden = optional(bool, true)   # If administrator_password_override is null, should Key Vault manage it?

    high_availability_mode                        = optional(string, "Disabled") # "Disabled", "ZoneRedundant", "SameZone"
    high_availability_standby_availability_zone   = optional(string, null)       # e.g., "1", "2", "3". Required if mode is not "Disabled".
    availability_zone                             = optional(string, null)       # Preferred AZ for the primary server or for SameZone HA, e.g., "1", "2", "3".

    backup_retention_days                         = optional(number, 7)
    geo_redundant_backup_enabled                  = optional(bool, false)

    maintenance_window_day_of_week                = optional(number, 0) # 0 (Sunday) to 6 (Saturday)
    maintenance_window_start_hour                 = optional(number, 1) # 0-23
    maintenance_window_start_minute               = optional(number, 0) # 0-59

    # Diagnostic Settings
    enable_diagnostic_settings                    = optional(bool, true)
    # If log_analytics_workspace_id_override is null, uses the shared workspace.
    log_analytics_workspace_id_override         = optional(string, null)
    # Valid categories: "PostgreSQLLogs", "SessionLogs", "QueryStoreRuntimeStatistics", "QueryStoreWaitStatistics", "AllLogs"
    diagnostic_log_categories_to_include          = optional(list(string), ["PostgreSQLLogs", "AllLogs"])
    # Valid categories: "AllMetrics"
    diagnostic_metric_categories_to_include       = optional(list(string), ["AllMetrics"])

    # Server Parameters (key-value map)
    # Example: { "autovacuum" = "on", "log_connections" = "on", "azure.extensions" = "PGVECTOR,UUID-OSSP" }
    server_parameters                             = optional(map(string), {})

    # Networking - Optional overrides if you need specific instances in different subnets/DNS zones
    # The subnet must be delegated to 'Microsoft.DBforPostgreSQL/flexibleServers'.
    subnet_id_override                            = optional(string, null)
    # If null, uses the shared private DNS zone created/specified at the top level.
    private_dns_zone_id_override                  = optional(string, null)

    tags                                          = optional(map(string), {}) # Additional tags specific to this instance
  }))
  default = {
    # Example instance (uncomment and modify to use)
    # "pgflex01" = {
    #   name_suffix    = "pgflex01"
    #   sku_name       = "GP_Standard_D2s_v3" # General Purpose, 2 vCores, 8 GiB RAM
    #   storage_gb     = 128
    #   version        = "15"
    #   administrator_login = "demoadmin"
    #   # administrator_password_override = "MySecureP@ssw0rd123!" # Uncomment to set a password directly
    #   high_availability_mode = "ZoneRedundant"
    #   high_availability_standby_availability_zone = "2" # Ensure your region supports this
    #   availability_zone = "1" # Ensure your region supports this
    #   backup_retention_days = 10
    #   server_parameters = {
    #     "log_connections" = "on"
    #     "log_statement"   = "ddl"
    #   }
    #   tags = {
    #     Environment = "dev"
    #   }
    # }
  }
}
