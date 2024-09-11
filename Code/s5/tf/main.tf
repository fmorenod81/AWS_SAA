
/* Comandos para ejecutar

aws ec2 create-key-pair --key-name Lab5a --query "KeyMaterial" --output text > Lab5a.pem
winscp.com /keygen "Lab5a.pem" /output="Lab5a.ppk"

terraform init
terraform plan
terraform apply
terraform output
terraform output --raw instance_ips >tmpFile
set /p A_IP= < tmpFile 
putty.exe -i "Lab5a.ppk" ec2-user@%A_IP%

Es necesario eliminar la ruta de eth0 que no tiene la conexion de salida
sudo route del -net 0.0.0.0 gw 172.20.0.1 netmask 0.0.0.0 dev eth0

terraform destroy --auto-approve
aws ec2 delete-key-pair --key-name Lab5a
del *.p*
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
  availability_zone = "us-east-1a"
  tags = {
    Name = "${local.common_name}_Public-Subnet-us-east-1a"
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

resource "aws_route_table_association" "us-east-1a-public" {
  subnet_id      = aws_subnet.us-east-1a-public.id
  route_table_id = aws_route_table.us-east-1a-public.id
}

data "aws_ami" "amazon-linux-2-ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
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
    Name       = "${local.common_name}_Web-Server_Lab5a",
    Group_Name = local.common_name,
  }
}



resource "aws_instance" "web-1" {
  ami                         = data.aws_ami.amazon-linux-2-ami.id
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
    volume_type           = "gp2"
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
