#!/bin/bash
echo "Creado desde Bootstrap. Lab AWS 4A- fmorenod.co 2024 - 19/07/2024 - 8:39 pm" >/home/ec2-user/DesdeBootstrap.txt
chown ec2-user:ec2-user /home/ec2-user/DesdeBootstrap.txt
python3 -m http.server 80