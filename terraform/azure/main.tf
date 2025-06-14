terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "your-terraform-state-rg"
  #   storage_account_name = "yourterraformstateaccount"
  #   container_name       = "tfstate"
  #   key                  = "azure-postgres/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

locals {
  prefixed_project_name = var.namespace == "" ? var.project_name : "${var.namespace}-${var.project_name}"
  global_tags = merge(var.common_tags, {
    Project   = local.prefixed_project_name
    Namespace = var.namespace
  })

  # Resource Group
  resource_group_name = coalesce(var.resource_group_name_override, "${local.prefixed_project_name}-rg")

  # Virtual Network
  vnet_name = coalesce(var.vnet_name_override, "${local.prefixed_project_name}-vnet")

  # Key Vault
  key_vault_name = coalesce(var.key_vault_name_override, "${substr(replace(lower(local.prefixed_project_name), "/[^a-z0-9]/", ""), 0, 17)}kv${random_string.kv_suffix.result}") # Max 24 chars, must be unique

  # Log Analytics Workspace
  log_analytics_workspace_name = coalesce(var.log_analytics_workspace_name_override, "${local.prefixed_project_name}-logs")
}

# Used for unique Key Vault naming if one is created
resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

# --- 1. Resource Group ---
resource "azurerm_resource_group" "main" {
  count    = var.resource_group_name_override == null || var.resource_group_name_override == "" ? 1 : 0
  name     = local.resource_group_name
  location = var.location
  tags     = local.global_tags
}

data "azurerm_resource_group" "existing" {
  count = var.resource_group_name_override != null && var.resource_group_name_override != "" ? 1 : 0
  name  = var.resource_group_name_override
}

# Determine which RG to use (created or existing)
locals {
  effective_resource_group_name     = var.resource_group_name_override == null || var.resource_group_name_override == "" ? azurerm_resource_group.main[0].name : data.azurerm_resource_group.existing[0].name
  effective_resource_group_location = var.resource_group_name_override == null || var.resource_group_name_override == "" ? azurerm_resource_group.main[0].location : data.azurerm_resource_group.existing[0].location
}

# --- 2. Virtual Network & Subnet ---
resource "azurerm_virtual_network" "main" {
  count               = var.vnet_name_override == null || var.vnet_name_override == "" ? 1 : 0
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = local.effective_resource_group_location
  resource_group_name = local.effective_resource_group_name
  tags                = local.global_tags
}

data "azurerm_virtual_network" "existing" {
  count               = var.vnet_name_override != null && var.vnet_name_override != "" ? 1 : 0
  name                = var.vnet_name_override
  resource_group_name = local.effective_resource_group_name # Assuming existing VNet is in the same RG
}

locals {
  effective_vnet_id   = var.vnet_name_override == null || var.vnet_name_override == "" ? azurerm_virtual_network.main[0].id : data.azurerm_virtual_network.existing[0].id
  effective_vnet_name = var.vnet_name_override == null || var.vnet_name_override == "" ? azurerm_virtual_network.main[0].name : data.azurerm_virtual_network.existing[0].name
}

resource "azurerm_subnet" "db_subnet" {
  # Create subnet only if VNet is being created by this module
  count                = var.vnet_name_override == null || var.vnet_name_override == "" ? 1 : 0
  name                 = var.db_subnet_name
  resource_group_name  = local.effective_resource_group_name
  virtual_network_name = local.effective_vnet_name
  address_prefixes     = [var.db_subnet_address_prefix]
  service_delegation {
    name    = "Microsoft.DBforPostgreSQL/flexibleServers"
    actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

data "azurerm_subnet" "existing_db_subnet" {
  # If VNet is existing, assume subnet also exists and is correctly delegated
  count                = var.vnet_name_override != null && var.vnet_name_override != "" ? 1 : 0
  name                 = var.db_subnet_name
  virtual_network_name = local.effective_vnet_name
  resource_group_name  = local.effective_resource_group_name
}

locals {
  effective_db_subnet_id = var.vnet_name_override == null || var.vnet_name_override == "" ? azurerm_subnet.db_subnet[0].id : data.azurerm_subnet.existing_db_subnet[0].id
}

# --- 3. Private DNS Zone for PostgreSQL ---
resource "azurerm_private_dns_zone" "postgresql" {
  name                = var.private_dns_zone_name_for_postgresql
  resource_group_name = local.effective_resource_group_name
  tags                = local.global_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_vnet_link" {
  name                  = "${local.effective_vnet_name}-pglink"
  resource_group_name   = local.effective_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = local.effective_vnet_id
  registration_enabled  = false # Flexible server handles registration
  tags                  = local.global_tags
}

# --- 4. Key Vault (Optional - for password management) ---
resource "azurerm_key_vault" "main" {
  count                     = (var.key_vault_name_override == null || var.key_vault_name_override == "") && anytrue([for k, v in var.database_instances : v.manage_password_in_key_vault_if_not_overridden && v.administrator_password_override == null]) ? 1 : 0
  name                      = local.key_vault_name
  location                  = local.effective_resource_group_location
  resource_group_name       = local.effective_resource_group_name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = var.key_vault_sku_name
  enabled_for_disk_encryption = false 
  enabled_for_deployment      = false 
  enabled_for_template_deployment = false 
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false 
  tags                      = local.global_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id 
    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
  }
}

data "azurerm_key_vault" "existing" {
  count               = var.key_vault_name_override != null && var.key_vault_name_override != "" ? 1 : 0
  name                = var.key_vault_name_override
  resource_group_name = local.effective_resource_group_name 
}

locals {
  create_new_key_vault = (var.key_vault_name_override == null || var.key_vault_name_override == "") && anytrue([for k, v in var.database_instances : v.manage_password_in_key_vault_if_not_overridden && v.administrator_password_override == null])
  effective_key_vault_id = local.create_new_key_vault ? (length(azurerm_key_vault.main) > 0 ? azurerm_key_vault.main[0].id : null) : (length(data.azurerm_key_vault.existing) > 0 ? data.azurerm_key_vault.existing[0].id : null)
}

# --- 5. Log Analytics Workspace (Optional - for diagnostics) ---
resource "azurerm_log_analytics_workspace" "main" {
  count               = (var.log_analytics_workspace_name_override == null || var.log_analytics_workspace_name_override == "") && anytrue([for k,v in var.database_instances : v.enable_diagnostic_settings]) ? 1 : 0
  name                = local.log_analytics_workspace_name
  location            = local.effective_resource_group_location
  resource_group_name = local.effective_resource_group_name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = 30 
  tags                = local.global_tags
}

data "azurerm_log_analytics_workspace" "existing" {
  count               = var.log_analytics_workspace_name_override != null && var.log_analytics_workspace_name_override != "" ? 1 : 0
  name                = var.log_analytics_workspace_name_override
  resource_group_name = local.effective_resource_group_name
}

locals {
  create_new_log_analytics_workspace = (var.log_analytics_workspace_name_override == null || var.log_analytics_workspace_name_override == "") && anytrue([for k,v in var.database_instances : v.enable_diagnostic_settings])
  effective_log_analytics_workspace_id = local.create_new_log_analytics_workspace ? (length(azurerm_log_analytics_workspace.main) > 0 ? azurerm_log_analytics_workspace.main[0].id : null) : (length(data.azurerm_log_analytics_workspace.existing) > 0 ? data.azurerm_log_analytics_workspace.existing[0].id : null)
}


# --- 6. PostgreSQL Flexible Server Instances ---
resource "random_password" "pg_password" {
  for_each = {
    for k, v in var.database_instances : k
    if v.administrator_password_override == null && v.manage_password_in_key_vault_if_not_overridden && local.effective_key_vault_id != null
  }
  length           = 24
  special          = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_key_vault_secret" "pg_password_secret" {
  for_each     = {
    for k, v in var.database_instances : k
    if v.administrator_password_override == null && v.manage_password_in_key_vault_if_not_overridden && local.effective_key_vault_id != null
  }
  name         = "${local.prefixed_project_name}-${each.value.name_suffix}-admin-password"
  value        = random_password.pg_password[each.key].result
  key_vault_id = local.effective_key_vault_id
  tags = merge(local.global_tags, {
    ServerName = "${local.prefixed_project_name}-${each.value.name_suffix}"
  })
  content_type = "password"

  lifecycle {
    ignore_changes = [value] 
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  for_each = var.database_instances

  name                = "${local.prefixed_project_name}-${each.value.name_suffix}"
  resource_group_name = local.effective_resource_group_name
  location            = local.effective_resource_group_location
  version             = each.value.version
  sku_name            = each.value.sku_name
  storage_mb          = each.value.storage_gb * 1024 

  administrator_login    = each.value.administrator_login
  administrator_password = each.value.administrator_password_override != null ? each.value.administrator_password_override : (
    each.value.manage_password_in_key_vault_if_not_overridden && local.effective_key_vault_id != null && contains(keys(random_password.pg_password), each.key) ? 
    random_password.pg_password[each.key].result : 
    null # This case should ideally not be hit if logic is correct, implies KV management desired but KV not available or password not generated
  )

  backup_retention_days        = each.value.backup_retention_days
  geo_redundant_backup_enabled = each.value.geo_redundant_backup_enabled

  dynamic "high_availability" {
    for_each = each.value.high_availability_mode != "Disabled" && each.value.high_availability_mode != null ? [1] : []
    content {
      mode                      = each.value.high_availability_mode
      standby_availability_zone = each.value.high_availability_standby_availability_zone
    }
  }
  availability_zone = each.value.availability_zone 

  delegated_subnet_id      = each.value.subnet_id_override != null ? each.value.subnet_id_override : local.effective_db_subnet_id
  private_dns_zone_id      = each.value.private_dns_zone_id_override != null ? each.value.private_dns_zone_id_override : azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false 

  dynamic "maintenance_window" {
    for_each = each.value.maintenance_window_day_of_week != null && each.value.maintenance_window_start_hour != null && each.value.maintenance_window_start_minute != null ? [1] : []
    content {
      day_of_week  = each.value.maintenance_window_day_of_week
      start_hour   = each.value.maintenance_window_start_hour
      start_minute = each.value.maintenance_window_start_minute
    }
  }
  
tags = merge(local.global_tags, each.value.tags, { Name = "${local.prefixed_project_name}-${each.value.name_suffix}" })

  lifecycle {
    ignore_changes = [
      administrator_password,
    ]
  }
}

# --- 6a. PostgreSQL Flexible Server Configurations (Parameters) ---
locals {
  # Flatten server parameters for easier iteration by azurerm_postgresql_flexible_server_configuration
  server_configurations_flat = flatten([
    for server_key, server_config in var.database_instances :
    [
      for param_name, param_value in server_config.server_parameters : {
        # Construct a unique key for the for_each map for the configuration resource
        config_resource_key = "${server_key}.${param_name}"
        server_tf_key       = server_key # To reference the server in azurerm_postgresql_flexible_server.main
        parameter_name      = param_name
        parameter_value     = param_value
      } if length(server_config.server_parameters) > 0
    ]
  ])
}

resource "azurerm_postgresql_flexible_server_configuration" "main" {
  for_each = { for config in local.server_configurations_flat : config.config_resource_key => config }

  name      = each.value.parameter_name
  server_id = azurerm_postgresql_flexible_server.main[each.value.server_tf_key].id
  value     = each.value.parameter_value
}


# --- 7. Diagnostic Settings for PostgreSQL Servers ---
resource "azurerm_monitor_diagnostic_setting" "pg_diag_settings" {
  for_each = {
    for k, v_server in azurerm_postgresql_flexible_server.main : k
    if var.database_instances[k].enable_diagnostic_settings && local.effective_log_analytics_workspace_id != null
  }

  name                       = "${each.value.name}-diag-settings"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = var.database_instances[each.key].log_analytics_workspace_id_override != null ? var.database_instances[each.key].log_analytics_workspace_id_override : local.effective_log_analytics_workspace_id

  dynamic "log" {
    for_each = var.database_instances[each.key].diagnostic_log_categories_to_include
    content {
      category = log.value
      enabled  = true
      retention_policy {
        enabled = false 
        days    = 0
      }
    }
  }

  dynamic "metric" {
    for_each = var.database_instances[each.key].diagnostic_metric_categories_to_include
    content {
      category = metric.value
      enabled  = true
      retention_policy {
        enabled = false
        days    = 0
      }
    }
  }
}
