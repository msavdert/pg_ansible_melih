variable "location" {
  description = "Azure region to deploy resources."
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "A name for the project, used to prefix resource names."
  type        = string
  default     = "pgproject"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group. If empty, one will be created."
  type        = string
  default     = "" # e.g., "my-existing-rg"
}

# PostgreSQL Flexible Server Specific Variables
variable "pg_server_name" {
  description = "Name of the PostgreSQL Flexible Server. If empty, one will be generated."
  type        = string
  default     = "" # e.g., "my-pgflex-server"
}

variable "pg_version" {
  description = "PostgreSQL version for the Flexible Server."
  type        = string
  default     = "16" # Check Azure for supported versions
}

variable "pg_admin_login" {
  description = "Administrator login name for the PostgreSQL server."
  type        = string
  default     = "pgadminuser"
}

variable "pg_admin_password_override" {
  description = "Administrator login password. If empty, a random one is generated. Sensitive."
  type        = string
  default     = ""
  sensitive   = true
}

variable "pg_sku_name" {
  description = "SKU name for the PostgreSQL server (e.g., GP_Standard_D2s_v3, B_Standard_B1ms)."
  type        = string
  default     = "B_Standard_B1ms" # Basic tier, for testing/dev
}

variable "pg_storage_mb" {
  description = "Max storage allowed for the PostgreSQL server in MB."
  type        = number
  default     = 32768 # 32 GB
}

variable "backup_retention_days" {
  description = "Backup retention days for the server."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable Geo-redundant backups."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled. Recommended false for production."
  type        = bool
  default     = true # Set to false and configure VNet integration for production
}

variable "allow_ip_address" {
  description = "An IP address to allow through the firewall. If empty, no specific IP rule is created."
  type        = string
  default     = "" # e.g., "203.0.113.42"
}

variable "allow_azure_services" {
  description = "Whether to allow Azure internal services to access the PostgreSQL server."
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone for the server. e.g. "1", "2", "3"."
  type        = string
  default     = "1" # Or null if not needed / let Azure decide
}

# High Availability (example, more complex than this)
# variable "ha_mode" {
#   description = "High availability mode. Can be ZoneRedundant or SameZone."
#   type        = string
#   default     = null # e.g. "ZoneRedundant"
# }
# variable "ha_standby_availability_zone" {
#   description = "Standby availability zone for HA. Required if ha_mode is ZoneRedundant."
#   type        = string
#   default     = null # e.g. "2"
# }

# Optional: Subscription and Tenant info if not using environment variables or CLI login
# variable "subscription_id" {
#   description = "Azure Subscription ID."
#   type        = string
#   default     = ""
# }
# variable "client_id" {
#   description = "Azure Client ID for Service Principal."
#   type        = string
#   default     = ""
# }
# variable "client_secret" {
#   description = "Azure Client Secret for Service Principal."
#   type        = string
#   default     = ""
#   sensitive   = true
# }
# variable "tenant_id" {
  # description = "Azure Tenant ID."
#   type        = string
#   default     = ""
# }
