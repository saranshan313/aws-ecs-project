locals {
  regions = {
    "use1" = "us-east-1"
  }
  settings = yamldecode(file("${var.TFC_WORKSPACE_NAME}.yaml"))

  tags = {
    region = local.settings.region
    env    = local.settings.env
  }

}

provider "aws" {
  region = local.regions[local.settings.region]
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket         = "tf-remote-state-234-343-555"
    key            = "env:/infra-${local.settings.env}-${local.settings.region}/infra-${local.settings.env}-${local.settings.region}/infra-${local.settings.env}-${local.settings.region}.tfstate"
    region         = local.regions[local.settings.region]
  }
}

