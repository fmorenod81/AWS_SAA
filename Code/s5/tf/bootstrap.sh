#!/bin/bash
yum update -y
amazon-linux-extras install docker -y
usermod -a -G docker ec2-user
echo "Creado desde Bootstrap. Lab AWS 5A- fmorenod.co 2021 - 19/06/2021 - 8:39 pm" >/home/ec2-user/DesdeBootstrap.txt
chown ec2-user:ec2-user /home/ec2-user/DesdeBootstrap.txt
service docker start