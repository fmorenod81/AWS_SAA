aws_profile = "default"

ssh_key = "Lab5a"

region = "us-east-1" # AWS Region, you can selected based on prices and the minimum number of AZ: 2

organization = "fmorenod"

project = "co"

vpc_cidr = {
  default = "172.20.0.0/22"
  dev     = "172.17.0.0/22"
  stg     = "172.18.0.0/22"
  prd     = "172.19.0.0/22"
}
public_subnet_cidr = {
  default = "172.20.0.0/24"
  dev     = "172.17.0.0/24"
  stg     = "172.18.0.0/24"
  prd     = "172.19.0.0/24"
}