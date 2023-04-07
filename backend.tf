terraform {
  backend "azurerm" {
    resource_group_name  = "storage001"
    storage_account_name = "stg22111"
    container_name       = "stss"
    key                  = "apim.tfstate"
  }
}