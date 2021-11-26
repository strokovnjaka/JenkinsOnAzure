variable "prefix" {
  default = "ucJenkins"
  description = "The prefix which should be used for all resources"
}

variable "location" {
  default = "West Europe"
  description = "The Azure Region in which all resources should be created."
}

locals {
  workdir = "${path.cwd}"
}
