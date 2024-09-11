variable "aws_profile" {
  type = string
  description = "AWS Profile for AWS Account; use this instead of AWS Access Key and Secret Key"
  default = "default"
}
variable "region" {
  type = string
  description = "AWS Region"
  default = "EMPTY"
}
