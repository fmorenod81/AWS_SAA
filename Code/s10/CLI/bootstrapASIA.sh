#!/bin/bash
yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
echo "Creado desde Bootstrap para Lab10" >/home/ec2-user/DesdeBootstrap.txt
chown ec2-user:ec2-user /home/ec2-user/DesdeBootstrap.txt
export AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
export PublicIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
docker run -d -p 80:80 -h $HOSTNAME --env NAME=ASIA:$AZ:$PublicIP --env PORT=80  --env PROTO=TCP --env VALUE=$AZ dockercloud/hello-world