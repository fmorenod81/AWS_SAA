variable "aws_profile" {
  type        = string
  description = "AWS Profile for AWS Account; use this instead of AWS Access Key and Secret Key"
  default     = "EMPTY"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "EMPTY"
}

variable "ssh_key" {
  type        = string
  description = "Keypair for EC2 Instances"
}

variable "organization" {
  type        = string
  description = "Enterprise Name"
  default     = "fmoreno"
}

variable "project" {
  type        = string
  description = "Acronym"
  default     = "-co"
}

variable "aws_region" {
  description = "EC2 Region for the VPC"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the Public Subnet"
  default     = "10.0.0.0/24"
}
variable "private_subnet_cidr" {
  description = "CIDR for the Private Subnet"
  default     = "10.1.0.0/24"
}

locals {
  env_name    = terraform.workspace
  common_name = "${var.organization}-${var.project}-${local.env_name}"
  region      = var.region
  availability_zones = ["${local.region}a", "${local.region}b"]
}