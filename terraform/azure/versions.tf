terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Specify a version constraint
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}
