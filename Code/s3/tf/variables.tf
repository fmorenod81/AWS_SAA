variable "aws_profile" {
  type        = string
  description = "AWS Profile for AWS Account; use this instead of AWS Access Key and Secret Key"
  default     = "default"
}
variable "region" {
  type        = string
  description = "AWS Region"
  default     = "EMPTY"
}
variable "bucketname" {
  type        = string
  description = "Name of the Bucket to apply rules"
  default     = "EMPTY"
}
locals {
  common_tags = "${var.bucketname}-TAG"
}
variable "tags" {
  default = {
    "owner"   = "www.fmorenod.co"
    "project" = "s3-replication"
  }
}


variable "destination_bucket" {
  default = "www.ocidemo1280.replicado"
}
variable "source_bucket" {
  default = "www.ocidemo1280.original"
}