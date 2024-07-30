variable "build_subnet" {
  type    = string
  default = "mypACKERSubnet"
}

variable "build_vnet" {
  type    = string
  default = "mypACKERvnet"
}

variable "build_key_vault" {
  type    = string
  default = ""
}

variable "locale" {
  type    = string
  default = "en-AU"
}

variable "build_resource_group" {
  type    = string
  default = "myPackerGroup"
}


variable "image_date" {
  type    = string
  default = "$(Build.BuildNumber)"
}

variable "image_offer" {
  type    = string
  default = "Windows-11"
}

variable "image_publisher" {
  type    = string
  default = "MicrosoftWindowsDesktop"
}

variable "image_sku" {
  type    = string
  default = "win11-23h2-ent"
}

variable "location" {
  type    = string
  default = "AustraliaEast"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v4"
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "winrmuser" {
  type    = string
  default = "packer"
}

variable "working_directory" {
  type    = string
  default = "${env("System_DefaultWorkingDirectory")}"
}

variable "packages_url" {
  type    = string
  default = "https://victajay.blob.core.windows.net/packages"
}

variable "apps_url" {
  type    = string
  default = "https://victajay.blob.core.windows.net/apps"
}

variable "destination_gallery_name" {
  type    = string
  default = "SIG_WindowsImages"
}

variable "destination_resource_group_name" {
  type    = string
  default = "RG-Images-AustratliaEast"
}

variable "managed_image_resource_group_name" {
  type    = string
  default = "RG-Images-AustratliaEast"
}

variable "destination_image_version" {
  type    = string
  default = "1.0.1"
}

variable "destination_replication_regions" {
  type    = string
  default = "australiaeast"
}

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

packer {
  required_plugins {
    windows-update = {
      version = "0.14.1"
      source = "github.com/rgl/windows-update"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  managed_image_name     = "${var.image_offer}-${var.image_sku}"
  destination_image_name = "windows11-definition1"
}

source "azure-arm" "microsoft-windows" {
  build_key_vault_name      = "${var.build_key_vault}"
  build_resource_group_name = "${var.build_resource_group}"
  client_id                 = var.client_id
  client_secret             = var.client_secret
  communicator              = "winrm"
  #The shared_image_gallery_destination block is available for publishing a new image version to an existing shared image gallery
  shared_image_gallery_destination {
    subscription        = "545a7b1a-0425-4cf0-95ac-825c1e4130e8"
    resource_group      = "${var.destination_resource_group_name}"
    gallery_name        = "${var.destination_gallery_name}"
    image_name          = "${local.destination_image_name}"
    image_version       = "${var.destination_image_version}"
    replication_regions = ["${var.location}"]
  }
  image_offer                            = "${var.image_offer}"
  image_publisher                        = "${var.image_publisher}"
  image_sku                              = "${var.image_sku}"
  image_version                          = "latest"
  #Specify the managed image name where the result of the Packer build will be saved. The image name must not exist ahead of time, and will not be overwritten
  managed_image_name                     = "${local.managed_image_name}"
  #Specify the managed image resource group name where the result of the Packer build will be saved. The resource group must already exist
  managed_image_resource_group_name      = "${var.managed_image_resource_group_name}"
  os_type                                = "Windows"
  private_virtual_network_with_public_ip = true
  subscription_id                        = var.subscription_id
  tenant_id                              = var.tenant_id
  virtual_network_name                   = "${var.build_vnet}"
  virtual_network_resource_group_name    = "${var.build_resource_group}"
  virtual_network_subnet_name            = "${var.build_subnet}"
  vm_size                                = "${var.vm_size}"
  winrm_insecure                         = true
  winrm_timeout                          = "10m"
  winrm_use_ssl                          = true
  winrm_username                         = "${var.winrmuser}"
}

build {
sources = ["source.azure-arm.microsoft-windows"]

provisioner "powershell" {
    environment_vars = ["Locale=${var.locale}",
                        "PackagesUrl=${var.packages_url}"]
    scripts          = ["build/rds/000_PrepImage.ps1",
                        "build/rds/011_SupportFunctions.ps1",
                        #"build/rds/013_RegionLanguage.ps1",
                        "build/rds/014_RolesFeatures.ps1",
                        "build/rds/015_Customise.ps1"]
  }

  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = ["New-Item -Path \"C:\\Apps\\Tools\" -ItemType \"Directory\" -Force -ErrorAction \"SilentlyContinue\" > $Null"]
  }

  provisioner "file" {
    source      = "${var.working_directory}/build/tools"
    destination = "C:\\Apps\\Tools"
    direction   = "upload"
    max_retries = "2"
  }

  provisioner "powershell" {
    environment_vars = ["AppsUrl=${var.apps_url}"]
    scripts = ["build/rds/FSLogixApps.ps1"]
   # "build/rds/200_MicrosoftOneDrive.ps1"]
  }

  provisioner "powershell" {
    scripts = ["build/rds/Sysprep-Image.ps1"]
  }

  post-processor "manifest" {
    output = "packer-manifest-${var.image_publisher}-${var.image_offer}-${var.image_sku}-${var.image_date}.json"
  }
}
