rem Prerequisito tener el putty completo en el path

rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Setear las variables de su grupo. Clase A: 10.x.x.x/8 Clase B: 172.16.x.x a 172.31.x.x
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"
set pbsn2_Mask="10.0.1.0/24"
set first_az="us-east-1a"
set second_az="us-east-1b"
set instance_type="t2.micro"

rem Crear la VPC y habilitar resolucion DNS
aws ec2 create-vpc --cidr-block %vpcn_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcn_Id% --enable-dns-hostnames "{\"Value\":true}" >tmpFile

rem Crear subred Publica 1
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 
rem Permitir que las instancias que se ejecutan en la subred se hagan publicas
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch >tmpFile

rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile
set /p IGW_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcn_Id% --internet-gateway-id %IGW_Id% >tmpFile

rem Crear tabla de ruteo publica y asignarle IGW como ruta por defecto
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW_Id% >tmpFile

rem Asociar la tabla de ruta a la subred
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id% >tmpFile

rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab5b --query "KeyMaterial" --output text > Lab5b.pem
winscp.com /keygen "Lab5b.pem" /output="Lab5b.ppk"

rem Crear los Security Groups para esa instancia
aws ec2 create-security-group --group-name "SecGroup_A" --description "Security group for Instance A" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_A_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 81 --cidr 0.0.0.0/0 >tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 82 --cidr 0.0.0.0/0 >tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile 


rem Crear subred Publica 2, ponerla public
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn2_Mask% --availability-zone %second_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn2_Id= < tmpFile 
aws ec2 modify-subnet-attribute --subnet-id %pbsn2_Id% --map-public-ip-on-launch >tmpFile 
aws ec2 associate-route-table  --subnet-id %pbsn2_Id% --route-table-id %Public_RT_Id% >tmpFile 
aws ec2 modify-subnet-attribute --subnet-id %pbsn2_Id% --map-public-ip-on-launch >tmpFile 

rem En el laboratorio de EC2 Inicial se mostrar la importancia de buscar una AMI correcto. 
rem AWS sugiere que se tome el AMI Amazon Linux 2 y se instale docker desde linea de comandos: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 

rem Se solicitan instancias y se adiciona un bootstrap para comprobar que el docker fue instalado
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab5b --security-group-ids %SecGroup_A_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A},{Key=ServerName,Value=A}]"  --user-data file://bootstrap.sh |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance1Id= <tmpFile
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab5b --security-group-ids %SecGroup_A_Id% --subnet-id %pbsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]"  --user-data file://bootstrap.sh |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance2Id= <tmpFile

rem Traer Datos especificos de instancia A. Revisar contenido describe-instances y Read_A.jq y contar en que lista esta para modificar el 1 por el valor deseado
aws ec2 describe-instances --filters "Name=tag:Name,Values=A"  "Name=instance-state-name,Values=running"  |  jq -r  ".Reservations[] | .Instances[]|.PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 

rem Traer Datos especificos de instancia A. Revisar contenido describe-instances y Read_A.jq y contar en que lista esta para modificar el 3 por el valor deseado
aws ec2 describe-instances --filters "Name=tag:Name,Values=B"  "Name=instance-state-name,Values=running"  |  jq -r  ".Reservations[] | .Instances[]|.PublicIpAddress" >tmpFile
set /p B_IP= < tmpFile 

rem Ingresar a ambas instancias publica por SSH. Ejecutar las mismas acciones y despues ir al navegador a ver que funcionan las IPs
putty.exe -i "Lab5b.ppk" ec2-user@%A_IP%
rem Comprobar la instalacion de Docker y borramos cualquier contenedor anterior
docker ps -a
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
rem Comprobar las instancias de docker. Se explica el mapeo de puerto, Zonar horarias y el ejemplo anterior
sudo docker run -d -p 80:80 -p 443:443 -e TZ=America/Bogota -h web2 fmorenod81/mtwa:web 
sudo docker run -d -p 81:80 -h web2 benpiper/r53-ec2-web
export AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
export PublicIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sudo docker run -d -p 82:80 -h $HOSTNAME --env NAME=$AZ:$PublicIP --env PORT=82  --env PROTO=TCP --env VALUE=$AZ dockercloud/hello-world

rem Se va al navegador y se visualizan con las IPs publicas los puertos 80, 443 y 82

rem Se hace el mismo procedimiento para la instancia B
putty.exe -i "Lab5b.ppk" ec2-user@%B_IP%

echo Se puede ir al navegador a las siguientes URLs: 
echo http://%A_IP% 
echo http://%A_IP%:81
echo http://%A_IP%:82
echo https://%A_IP%

echo Se puede ir al navegador a las siguientes URLs: 
echo http://%B_IP% 
echo http://%B_IP%:81
echo http://%B_IP%:82
echo https://%B_IP%

rem ************** Seccion Nueva *****

rem Crear los Security Group del Balanceador
aws ec2 create-security-group --group-name "SecGroup_ALB" --description "Security group for ALB" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_ALB_Id= < tmpFile
rem Se agrega la autorizacion para IPv6 al security group de entrada. Se agrega IPv6 como entrada al ALB
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=0:0:0:0::/0}] >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges=[{CidrIpv6=0:0:0:0::/0}] >tmpFile
rem Permitir que el balanceador pueda ver las instancias, sirve para el balanceo y el healthcheck
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 80 --source-group %SecGroup_ALB_Id% >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 81 --source-group %SecGroup_ALB_Id% >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 82 --source-group %SecGroup_ALB_Id% >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 443 --source-group %SecGroup_ALB_Id% >tmpFile


rem Crear los target groups y registrar las instancias a los mismos en cada puerto
aws elbv2 create-target-group --name TG-Port-80 --protocol HTTP --port 80 --target-type instance --vpc-id %vpcn_Id% |jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG80_ARN= < tmpFile 
aws elbv2 register-targets --target-group-arn %TG80_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%
aws elbv2 create-target-group --name TG-Port-81 --protocol HTTP --port 81 --target-type instance --vpc-id %vpcn_Id%|jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG81_ARN= < tmpFile 
aws elbv2 register-targets --target-group-arn %TG81_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%
aws elbv2 create-target-group --name TG-Port-82 --protocol HTTP --port 82 --target-type instance --vpc-id %vpcn_Id%|jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG82_ARN= < tmpFile 
aws elbv2 register-targets --target-group-arn %TG82_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%

rem Crear el Balanceador
aws elbv2 create-load-balancer --name ALBLab5b --subnets %pbsn1_Id% %pbsn2_Id% --security-groups %SecGroup_ALB_Id% >tmpFile2
type tmpFile2|jq ".LoadBalancers[].LoadBalancerArn" >tmpFile
set /p LB_ARN= < tmpFile
type tmpFile2|jq ".LoadBalancers[].DNSName" >tmpFile
set /p LB_DNSName= < tmpFile
del tmpFile2


rem Se crea el Listener para Puerto 80
aws elbv2 create-listener --load-balancer-arn %LB_ARN% --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=%TG80_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST80_ARN= < tmpFile
rem Se espera que el balanceador este en estado Active
aws elbv2 describe-load-balancers|jq "{DNSName: .LoadBalancers[].DNSName, Status:.LoadBalancers[].State.Code}"
rem Se prueba que el ALB llegue al target group desde un navegador
echo Con el navegador ir a %LB_DNSName%
rem Se crea el Listener para Puerto 81, 82
aws elbv2 create-listener --load-balancer-arn %LB_ARN% --protocol HTTP --port 81 --default-actions Type=forward,TargetGroupArn=%TG81_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST81_ARN= < tmpFile
aws elbv2 create-listener --load-balancer-arn %LB_ARN% --protocol HTTP --port 82 --default-actions Type=forward,TargetGroupArn=%TG82_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST82_ARN= < tmpFile
rem Probar porque no funciona en los puertos 81, 82 y 443
rem Habilitar los sec group al ALB
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --protocol tcp --port 81 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ALB_Id% --protocol tcp --port 82 --cidr 0.0.0.0/0 >tmpFile
rem Probar porque funciona en los puertos 81, 82
echo Con el navegador ir a %LB_DNSName%:81
echo Con el navegador ir a %LB_DNSName%:82

rem Crear la regla para el puerto 80 y que cumpla el path del archivo JSON
aws elbv2 create-rule --listener-arn %LST80_ARN% --priority 5 --conditions file://conditions-pattern-port81.json --actions Type=forward,TargetGroupArn=%TG81_ARN% >tmpFile
aws elbv2 create-rule --listener-arn %LST80_ARN% --priority 4 --conditions file://conditions-pattern-port82.json --actions Type=forward,TargetGroupArn=%TG82_ARN% >tmpFile
rem Revisar las rutas del balanceador
echo Con el navegador ir a %LB_DNSName%/port81
echo Con el navegador ir a %LB_DNSName%/port82


rem ----- ELIMINAR RECURSOS ----
aws ec2 terminate-instances --instance-ids %Instance1Id% %Instance2Id%
aws elbv2 delete-load-balancer --load-balancer-arn %LB_ARN%
rem Algunas veces toca esperar que finalicen las instancias antes de continuar
aws ec2 delete-security-group --group-id %SecGroup_A_Id%
aws ec2 delete-security-group --group-id %SecGroup_ALB_Id%
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-subnet --subnet-id %pbsn2_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%
aws ec2 delete-key-pair --key-name Lab5b
aws elbv2 delete-target-group --target-group-arn %TG80_ARN%
aws elbv2 delete-target-group --target-group-arn %TG81_ARN%
aws elbv2 delete-target-group --target-group-arn %TG82_ARN%
del Lab5b.pem
del Lab5b.ppk
del tmpFile
rem Opcional. Conocer la IP del Contenedor interna
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <Nombre_Contenedor>


