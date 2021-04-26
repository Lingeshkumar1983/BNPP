# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
      
    }
  }
}

//data "azurerm_subscription" "current" {
//}

//output "current_subscription_display_name" {
//  value = data.azurerm_subscription.current.display_name
//  }

//output "current_subscription_id" {
//  value = data.azurerm_subscription.current.subscription_id
 // }

//data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
  //skip_provider_registration=true
  subscription_id=var.subscription_id
  client_id=var.service_principal_id
  client_secret=var.service_principal_key
  tenant_id=var.tenant_id
}

/*resource "azurerm_resource_provider_registration" "resource_reg_purview" {
  name = "Microsoft.Purview"
}

resource "azurerm_resource_provider_registration" "resource_reg_storage" {
  name = "Microsoft.Storage"
}

resource "azurerm_resource_provider_registration" "resource_reg_eventhub" {
  name = "Microsoft.EventHub"
}*/


resource "azurerm_resource_group" "rg" {
  name     = "${var.companyprefix}-rg"
  location = "West Europe"
}

resource "azurerm_network_security_group" "azure_vm_sg" {
  name                = "${var.companyprefix}-sg-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_virtual_network" "azure_vn" {
  name                = "${var.companyprefix}-vn-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name           = "${var.companyprefix}-subnet1"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "${var.companyprefix}-subnet2"
    address_prefix = "10.0.2.0/24"
  }

}


resource "azurerm_policy_definition" "purview_policy_def" {
  name         = "${var.companyprefix}-purview-bypass"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Purview Bypass"

  policy_rule = <<POLICY_RULE
  {
      "if": {
        "anyOf": [
          {
            "allOf": [
              {
                "field": "type",
                "equals": "Microsoft.Storage/storageAccounts"
              },
              {
                "not": {
                  "field": "tags['resourceBypass']",
                  "exists": true
                }
              }
            ]
          },
          {
            "allOf": [
              {
                "field": "type",
                "equals": "Microsoft.EventHub/namespaces"
              },
              {
                "not": {
                  "field": "tags['resourceBypass']",
                  "exists": true
                }
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  
POLICY_RULE
}


resource "azurerm_policy_assignment" "purview_policy_assg" {
  name                 = "purview_policy_bypass"
  //scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}"
scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}"
  policy_definition_id = azurerm_policy_definition.purview_policy_def.id
  description          = "Policy Assignment purview"
  display_name         = "purview policy bypass assignment to RM"

  metadata = <<METADATA
    {
    "category": "General"
    }
METADATA

}



resource "azurerm_storage_account" "storagegroup" {
  name                     = "${var.companyprefix}storage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

   tags = {
    resourceBypass = "allowed"
  }
}

resource "azurerm_storage_container" "blobstorage" {
   count = length(var.component)
   name  = "raw-${element(var.component, count.index)}"
   storage_account_name = azurerm_storage_account.storagegroup.name
   container_access_type = "private"
}
resource "azurerm_storage_blob" "blobobject" {
  depends_on=  ["azurerm_storage_container.blobstorage"]
  // count = length(var.component_storage.containers)
   name = "FL_insurance_sample.csv"
   storage_account_name = azurerm_storage_account.storagegroup.name
  // storage_container_name = "raw-${element(var.component_storage.containers, count.index)}"
  storage_container_name="raw-csv"
   type                   = "Block"
   source="srcFiles/FL_insurance_sample.csv"
}

resource "azurerm_storage_blob" "blobojsonbject" {
   depends_on=  ["azurerm_storage_container.blobstorage"]
  #  count = length(var.component_storage.containers)
   name = "sample.json"
   storage_account_name = azurerm_storage_account.storagegroup.name
  #  storage_container_name = "raw-${element(var.component_storage.containers, count.index)}"
  storage_container_name="raw-json"
   type                   = "Block"
   source="srcFiles/sample.json"
}

resource "azurerm_storage_blob" "blobounstructuredbject" {
   depends_on=  ["azurerm_storage_container.blobstorage"]
  #  count = length(var.component_storage.containers)
   name = "1-Penguins.pdf"
   storage_account_name = azurerm_storage_account.storagegroup.name
  #  storage_container_name = "raw-${element(var.component_storage.containers, count.index)}"
  storage_container_name="raw-unstructured"
   type                   = "Block"
   source="srcFiles/1-Penguins.pdf"
}


resource "azurerm_purview_account" "purview_account" {
  name                = "${var.companyprefix}-purview-client-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location  = azurerm_resource_group.rg.location
  sku_name               = "Standard_4"
  public_network_enabled = true

   tags = {
    resourceBypass = "allowed"
  }
}

resource "azurerm_role_assignment" "az_purview_userrole_curator" {
  # name               = azurerm_storage_account.ortechastoragegroup.resource_manager_id
//depends_on=  ["azurerm_storage_container.blobstorage"]
  scope              = azurerm_purview_account.purview_account.id
  role_definition_name= "Purview Data Curator"
  principal_id       = "${var.admin_user_object_id}"
}

resource "azurerm_role_assignment" "az_purview_userrole_data_source" {
  # name               = azurerm_storage_account.ortechastoragegroup.resource_manager_id
//depends_on=  ["azurerm_storage_container.blobstorage"]
  scope              = azurerm_purview_account.purview_account.id
  role_definition_name= "Purview Data Source Administrator"
  principal_id       = "${var.admin_user_object_id}"
}

resource "azurerm_role_assignment" "az_role_purview" {
  # name               = azurerm_storage_account.ortechastoragegroup.resource_manager_id
//depends_on=  ["azurerm_storage_container.blobstorage"]
  scope              = azurerm_storage_account.storagegroup.id
  role_definition_name= "Storage Blob Data Reader"
  principal_id       = azurerm_purview_account.purview_account.identity[0]["principal_id"]
}

resource "azurerm_sql_server" "az_ortecha_sqlserver" {
  name                         = "${var.companyprefix}-sqlserver-1"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "ortecha-sqlserver-admin"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_sql_database" "example" {
  name                = "ortecha-sqldb-1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.az_ortecha_sqlserver.name
  #edition                     = "Basic"
  tags = {
    environment = "dev"
  }
}


resource "azurerm_key_vault" "keyvalut" {
  name                       = "sqlserver-1-key"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  //tenant_id                  = data.azurerm_client_config.current.tenant_id
  tenant_id                  = "${var.tenant_id}"
  sku_name = "standard"

  access_policy {
    tenant_id = "${var.tenant_id}" //data.azurerm_client_config.current.tenant_id
    object_id= "${var.service_principal_object_id}" //data.azurerm_client_config.current.object_id

     key_permissions = [
"get","list","update","create","import","delete","recover","backup","restore",
     ]

secret_permissions = [
  "get","list","delete","recover","backup","restore","set","purge"
     ]

  }
}

resource "azurerm_key_vault_secret" "az_kv_sec" {
  name         = "${var.companyprefix}-strawberry"
  value        = "4-v3ry-53cr37-p455w0rd"
  key_vault_id = azurerm_key_vault.keyvalut.id
}


resource "azurerm_key_vault_access_policy" "az_kv_acess_pol" {
  key_vault_id = azurerm_key_vault.keyvalut.id
  tenant_id    = "${var.tenant_id}"  //data.azurerm_client_config.current.tenant_id
  object_id       = azurerm_purview_account.purview_account.identity[0]["principal_id"]


  secret_permissions = [
    "get","list"
  ]
}

resource "azurerm_key_vault_access_policy" "az_kv_user_acess_pol" {
  key_vault_id = azurerm_key_vault.keyvalut.id
  tenant_id    = "${var.tenant_id}"  //data.azurerm_client_config.current.tenant_id
  object_id       = "${var.admin_user_object_id}"


  secret_permissions = [
    "get","list"
  ]
}



resource "azurerm_data_factory" "az_df" {
  name                = "${var.companyprefix}-df-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_data_lake_store" "azdl" {
  name                = "${var.companyprefix}dl01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  encryption_state    = "Enabled"
  encryption_type     = "ServiceManaged"
}

// resource "azurerm_data_lake_store_file" "az_dl_sample" {
//   local_file_path     = "srcFiles/FL_insurance_sample.csv"
//   remote_file_path    = "/Inbound/csv/FL_insurance_sample.csv"
// }