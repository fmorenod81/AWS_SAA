
/* Comandos para ejecutar

aws ec2 create-key-pair --key-name Lab4a --query "KeyMaterial" --output text > Lab4a.pem
winscp.com /keygen "Lab4a.pem" /output="Lab4a.ppk"

terraform init
terraform plan
terraform apply 
terraform ouput
terraform output -raw web_ip >tmpFile
set /p Web_IP= < tmpFile 
echo http://%Web_IP%
terraform output -raw private_ip

putty.exe -i "Lab4a.ppk" ec2-user@%Web_IP%

psftp.exe -i "Lab4a.ppk" ec2-user@%Web_IP%
put Lab4a.pem
chmod 400 Lab4a.pem
exit

ssh -i Lab4a.pem ec2-user@<private_ip>

terraform destroy --auto-approve
aws ec2 delete-key-pair --key-name Lab4a
del Lab4a.pem
del Lab4a.ppk
del tmpFile
*/

terraform {
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

/* NETWORKING */
/* VPC, IGW */
resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr[terraform.workspace]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name       = "${local.common_name}-vpc",
    Group_Name = local.common_name,
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name       = "${local.common_name}_Internet-Gateway",
    Group_Name = local.common_name,
  }
}


/* SUBNET */
resource "aws_subnet" "us-east-1a-public" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(var.vpc_cidr[terraform.workspace], 2, 0)
  availability_zone       = element(local.availability_zones, 0)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.common_name}_Public-Subnet-us-east-1a"
  }
}
resource "aws_subnet" "us-east-1b-private" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(var.vpc_cidr[terraform.workspace], 2, 1)
  availability_zone       = element(local.availability_zones, 1)
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.common_name}_Private-Subnet-us-east-1b"
  }
}
# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.default]
   tags = {
    Name = "${local.common_name}_EIP-NAT-GW"
  }
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.us-east-1a-public.id
  tags = {
    Name = "${local.common_name}_EIP-NAT-GW"
  }
}

resource "aws_route_table" "us-east-1a-public" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name       = "${local.common_name}_Public-Route-Table",
    Group_Name = local.common_name,
  }
}
resource "aws_route_table" "us-east-1b-private" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name       = "${local.common_name}_Private-Route-Table",
    Group_Name = local.common_name,
  }
}
resource "aws_route_table_association" "us-east-1a-public" {
  subnet_id      = aws_subnet.us-east-1a-public.id
  route_table_id = aws_route_table.us-east-1a-public.id
}
resource "aws_route_table_association" "us-east-1b-private" {
  subnet_id      = aws_subnet.us-east-1b-private.id
  route_table_id = aws_route_table.us-east-1b-private.id
}
data "aws_ami" "base_ami" {
  most_recent      = true
  owners           = ["amazon"]
 
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
 
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
 
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
 
}
/*
  Web Servers
*/
resource "aws_security_group" "web" {
  name        = "vpc_devops_server"
  description = "Allow incoming HTTP connections."

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.default.id

  tags = {
    Name       = "${local.common_name}_Web-Server_Lab4a",
    Group_Name = local.common_name,
  }
}
resource "aws_instance" "web-1" {
  ami                         = data.aws_ami.base_ami.id
  availability_zone           = "us-east-1a"
  instance_type               = "t3.micro"
  key_name                    = var.ssh_key
  vpc_security_group_ids      = [aws_security_group.web.id]
  subnet_id                   = aws_subnet.us-east-1a-public.id
  associate_public_ip_address = false
  source_dest_check           = false
  user_data                   = file("bootstrap.sh")
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = false
  }
  tags = {
    Name = "${local.common_name}_Web_Server"
  }
}

resource "aws_network_interface" "web-eni" {
  subnet_id       = aws_subnet.us-east-1a-public.id
  security_groups = [aws_security_group.web.id]
  depends_on      = [aws_instance.web-1]
  attachment {
    instance     = aws_instance.web-1.id
    device_index = 1
  }
}

resource "aws_eip" "web-eip" {
  network_interface = aws_network_interface.web-eni.id
  depends_on        = [aws_network_interface.web-eni]
  tags = {
    Name       = "${local.common_name}_Elastic-IP-For-ENI",
    Group_Name = local.common_name
  }
}

resource "aws_instance" "private-1" {
  ami                         = data.aws_ami.base_ami.id
  availability_zone           = "us-east-1b"
  instance_type               = "t3.micro"
  key_name                    = var.ssh_key
  vpc_security_group_ids      = [aws_security_group.web.id]
  subnet_id                   = aws_subnet.us-east-1b-private.id
  associate_public_ip_address = false
  source_dest_check           = false
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = false
  }
  tags = {
    Name = "${local.common_name}_Private_Server"
  }
}