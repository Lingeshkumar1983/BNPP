# Configure the Azure provider
variable "companyprefix" {
  default="ortecha"
}

variable "projectprefix" {
  default="clientdemo"
}


variable "component" {
  type    = list
  default = ["csv", "json", "unstructured", "others"]
}

variable "service_principal_id" {
  default="d0b4be50-435f-4635-8431-041ec7bff160"
}

variable "service_principal_key" {
  default="Rj53-QN.8IU5dOt.zqUT4F_-Nzb8o29KAp"
}

variable "tenant_id" {
  default="f4e5183f-317b-4772-b87b-23dc28abd203"
}

variable "subscription_id" {
  default="900900c6-5135-4078-a4b6-e5aac4d23ba4"
}

variable "service_principal_object_id" {
  default="cdaef324-b2d1-4527-aa09-2890aef638e4"
}


variable "admin_user_object_id" {
  default="c5823ac3-d8d2-4866-ad4f-ae852c96dcc7"
}
