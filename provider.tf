terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "=2.2.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = true
      purge_soft_delete_on_destroy       = true
      recover_soft_deleted_key_vaults    = true
      recover_soft_deleted_keys          = true
    }
  }
  subscription_id = var.subscription_id
}