# Configure the provider
 terraform {
   required_providers {
     azurerm = {
       source  = "hashicorp/azurerm"
       version = "=3.28.0"
     }
 }
}
 provider "azurerm" {
   features {}
}

# --- Get reference to logged on Azure subscription ---
data "azurerm_client_config" "current" {}

# Create a new resource group
resource "azurerm_resource_group" "rg" {
  name     = "mph-apim-23"
  location = "West Europe"
}


# --- Storage Account  --

resource "azurerm_storage_account" "sa" {
  name                     = "2023apimstg"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  enable_https_traffic_only= true
}
resource "azurerm_storage_container" "saContainerApim" {
  name                  = "apim-files"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}
resource "azurerm_storage_container" "saContainerApi" {
  name                  = "api-files"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}
# -----key vault---
resource "azurerm_key_vault" "kv" {
  name                        = "mph-apim-keyvault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
}

# set key vault permissions
resource "azurerm_key_vault_access_policy" "kvPermissions" {
  key_vault_id = azurerm_key_vault.kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get"
  ]

  # Give full control to the sevice principal as it might need to delete a certificate on the next update run
  certificate_permissions = [
    "Create",
    "Delete",
    "Get",
    "Import",
    "List",
    "Update"
  ]
}

# Upload certificate to Key vault
resource "azurerm_key_vault_certificate" "kvCertificate" {
  name         = "apim-tls-certificate"
  key_vault_id = azurerm_key_vault.kv.id


  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }
  }
}

# --- API Management  --
resource "azurerm_api_management" "apim" {
  name                = "mph-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Didago IT Consultancy"
  publisher_email     = "apim-tst@yourcompany.nl"

  sku_name            = "Developer_1"

  identity {
    type = "SystemAssigned"
  }
}

// # Create Application Insights
// resource "azurerm_application_insights" "ai" {
//   name                = "mph-apim-app-insight"
//   location            = azurerm_resource_group.rg.location
//   resource_group_name = azurerm_resource_group.rg.name
//   application_type    = "web"
// }
// # Create Logger
// resource "azurerm_api_management_logger" "apimLogger" {
//   name                = "mph-apim-logger"
//   api_management_name = azurerm_api_management.apim.name
//   resource_group_name = azurerm_resource_group.rg.name

//   application_insights {
//     instrumentation_key = azurerm_application_insights.ai.instrumentation_key
//   }
// }

// resource "azurerm_api_management_logger" "logger2023" {
//   name                = "apim-logger"
//   api_management_name = azurerm_api_management.apim.name
//   resource_group_name = azurerm_resource_group.rg.name
//   resource_id         = azurerm_application_insights.ai.id

//   application_insights {
//     instrumentation_key = azurerm_application_insights.ai.instrumentation_key
//   }
// }



// resource "azurerm_monitor_diagnostic_setting" "example" {
//   name               = "apim-setg"
//   target_resource_id = azurerm_api_management.apim.id
//   //storage_account_id = azurerm_storage_account.example.id

//   log {
//     category = "AllLogs"
//     enabled  = true

//     retention_policy {
//       enabled = true
//       days    = 30
//     }
//   }

//   log {
//     category = "AuditLogs"
//     enabled  = true

//     retention_policy {
//       enabled = true
//       days    = 30
//     }
//   }

//   metric {
//     category = "AllMetrics"
//     enabled  = true

//     retention_policy {
//       enabled = true
//       days    = 30
//     }
//   }
// }

// # Assign get certificate permissions to APIM managed identity so it can access the certificate in key vault
// resource "azurerm_key_vault_access_policy" "kvApimPolicy" {
//   key_vault_id = azurerm_key_vault.kv.id

//   tenant_id = data.azurerm_client_config.current.tenant_id
//   object_id = azurerm_api_management.apim.identity.0.principal_id

//   secret_permissions = [
//     "Get"
//   ]

//   certificate_permissions = [
//     "Get",
//     "List"
//   ]
// }

// # Run script to apply host configuration, which is only possible when APIM managed identity has access to Key Vault certificate store
// resource "null_resource" "apimManagementHostConfiguration" {
//   provisioner "local-exec" {
//     command = "scripts/SetApimHostConfiguration.ps1 -resourceGroupName ${azurerm_resource_group.rg.name} -apimServiceName ${azurerm_api_management.apim.name} -apiProxyHostname \"portal.mph.nl\"\n -kvCertificateSecret ${azurerm_key_vault_certificate.kvCertificate.secret_id}"
//     interpreter = ["PowerShell", "-Command"]
//   }
//   depends_on = [azurerm_api_management.apim, azurerm_key_vault_access_policy.kvApimPolicy]
// }

// // # --- Products section --
// // # Create Product for APIM management
// // resource "azurerm_api_management_product" "product" {
// //   product_id            = "some-product"
// //   api_management_name   = azurerm_api_management.apim.name
// //   resource_group_name   = azurerm_resource_group.rg.name
// //   display_name          = "some-Product"
// //   subscription_required = true
// //   subscriptions_limit   = 10
// //   approval_required     = true
// //   published             = true
// // }
// // # Set product policy
// // resource "azurerm_api_management_product_policy" "productPolicy" {
// //   product_id          = azurerm_api_management_product.product.id
// //   api_management_name = azurerm_api_management.apim.name
// //   resource_group_name = azurerm_resource_group.rg.name
// //   xml_content = <<XML
// //     <policies>
// //       <inbound>
// //         <base />
// //       </inbound>
// //       <backend>
// //         <base />
// //       </backend>
// //       <outbound>
// //         <set-header name="Server" exists-action="delete" />
// //         <set-header name="X-Powered-By" exists-action="delete" />
// //         <set-header name="X-AspNet-Version" exists-action="delete" />
// //         <base />
// //       </outbound>
// //       <on-error>
// //         <base />
// //       </on-error>
// //     </policies>
// //   XML
// //   depends_on = [azurerm_api_management_product.product]
// // }

// // # --- Users section --
// // # Create Users
// // resource "azurerm_api_management_user" "user" {
// //   user_id             = "apimuser2023"
// //   api_management_name = azurerm_api_management.apim.name
// //   resource_group_name = azurerm_resource_group.rg.name
// //   first_name          = "User"
// //   last_name           = "apim"
// //   email               = "ambika.awari@mphasis.com"
// //   state               = "active"
// // }

// // # --- Subscriptions section --
// // # Create Subscriptions
// // resource "azurerm_api_management_subscription" "subscription" {
// //   api_management_name = azurerm_api_management.apim.name
// //   resource_group_name = azurerm_resource_group.rg.name
// //   product_id          = azurerm_api_management_product.product.id
// //   user_id             = azurerm_api_management_user.user.id
// //   display_name        = "Some subscription"
// //   state               = "active"
// // }




// // # --- Default API for health checks ---
// // # Create API
// // resource "azurerm_api_management_api" "apiHealthProbe" {
// // name                = "health-probe"
// // resource_group_name = azurerm_resource_group.rg.name
// // api_management_name = azurerm_api_management.apim.name
// // revision            = "1"
// // display_name        = "Health probe"
// // path                = "health-probe"
// // protocols           = ["https"]

// //   subscription_key_parameter_names  {
// //     header = "some-custom-key-guid-tst"
// //     query = "some-custom-key-guid-tst"
// //   }

// //   import {
// //     content_format = "swagger-json"
// //     content_value  = <<JSON
// //       {
// //           "swagger": "2.0",
// //           "info": {
// //               "version": "1.0.0",
// //               "title": "Health probe"
// //           },
// //           "host": "not-used-direct-response",
// //           "basePath": "/",
// //           "schemes": [
// //               "https"
// //           ],
// //           "consumes": [
// //               "application/json"
// //           ],
// //           "produces": [
// //               "application/json"
// //           ],
// //           "paths": {
// //               "/": {
// //                   "get": {
// //                       "operationId": "get-ping",
// //                       "responses": {}
// //                   }
// //               }
// //           }
// //       }
// //     JSON
// //   }
// // }
// // # set api level policy
// // resource "azurerm_api_management_api_policy" "apiHealthProbePolicy" {
// //   api_name            = azurerm_api_management_api.apiHealthProbe.name
// //   api_management_name = azurerm_api_management.apim.name
// //   resource_group_name = azurerm_resource_group.rg.name

// //   xml_content = <<XML
// //     <policies>
// //       <inbound>
// //         <return-response>
// //             <set-status code="200" />
// //         </return-response>
// //         <base />
// //       </inbound>
// //     </policies>
// //   XML
// // }
// // # Assign API to Management product in APIM
// // resource "azurerm_api_management_product_api" "apiProduct" {
// //   api_name            = azurerm_api_management_api.apiHealthProbe.name
// //   product_id          = azurerm_api_management_product.product.product_id
// //   api_management_name = azurerm_api_management.apim.name
// //   resource_group_name = azurerm_resource_group.rg.name
// // }