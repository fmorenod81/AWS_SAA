rem Prerequisito tener el putty completo en el path
rem Tener un convertidor de base64 en Windows ya esta y se llama certutil en otro caso, buscar en Web o MacOs openssl base64 -in <infile> -out <outfile>

rem Clave del usuario
rem set AWS_ACCESS_KEY_ID=
rem set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Setear las variables de su grupo. Clase A: 10.x.x.x/8 Clase B: 172.16.x.x a 172.31.x.x
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"
set pbsn2_Mask="10.0.1.0/24"
set vpcp_Mask="172.16.0.0/16"
set pbsp1_Mask="172.16.0.0/24"
set pbsp2_Mask="172.16.1.0/24"
set pbsn3_Mask="172.16.2.0/24"

set first_az="us-east-1a"
set second_az="us-east-1c"
set instance_type="t3.micro"

rem Crear las VPC y habilitar resolucion DNS
aws ec2 create-vpc --cidr-block %vpcn_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcn_Id% --enable-dns-hostnames "{\"Value\":true}"
aws ec2 create-vpc --cidr-block %vpcp_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcp_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcp_Id% --enable-dns-hostnames "{\"Value\":true}"

rem Crear subredes Publicas
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn2_Mask% --availability-zone %second_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn2_Id= < tmpFile 
rem Permitir que las instancias que se ejecutan en la subredes se hagan publicas. Ver https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch >tmpFile
aws ec2 modify-subnet-attribute --subnet-id %pbsn2_Id% --map-public-ip-on-launch >tmpFile

rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile >tmpFile
set /p IGW_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcn_Id% --internet-gateway-id %IGW_Id% >tmpFile

rem Crear tabla de ruteo publica y asignarle IGW como ruta por defecto
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW_Id%

rem Asociar la tabla de ruta a las subredes
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id% >tmpFile
aws ec2 associate-route-table  --subnet-id %pbsn2_Id% --route-table-id %Public_RT_Id% >tmpFile

rem Redes privadas

rem Crear subredes Privadas y la unica publica para el NAT
aws ec2 create-subnet --vpc-id %vpcp_Id% --cidr-block %pbsp1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsp1_Id= < tmpFile 
aws ec2 create-subnet --vpc-id %vpcp_Id% --cidr-block %pbsp2_Mask% --availability-zone %second_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsp2_Id= < tmpFile 
aws ec2 create-subnet --vpc-id %vpcp_Id% --cidr-block %pbsn3_Mask% --availability-zone %second_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn3_Id= < tmpFile 

rem Solicitar una IP Elastica para hacer el Nat Gateway
aws ec2 allocate-address --domain vpc |jq ".AllocationId" >tmpFile
set /p NAT_EIP= < tmpFile 

rem Crear el NAT Gateway, asignarlo a una EIP Anterior.
aws ec2 create-nat-gateway --subnet-id  %pbsn3_Id% --allocation-id %NAT_EIP%|jq ".NatGateway.NatGatewayId" >tmpFile
set /p NATGW_Id= < tmpFile 

rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile
set /p IGW2_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcp_Id% --internet-gateway-id %IGW2_Id% >tmpFile

rem Crear tabla de ruteo publica de la NAT para las redes privadas y asignar el IGW como ruta por defecto. Asociarla
aws ec2 create-route-table --vpc-id %vpcp_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_Private_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_Private_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW2_Id% >tmpFile
aws ec2 associate-route-table  --subnet-id %pbsn3_Id% --route-table-id %Public_Private_RT_Id% >tmpFile


rem Crear tabla de ruteo publica para las redes privadas y asignar el NAT GW como ruta por defecto. Asociarla
aws ec2 create-route-table --vpc-id %vpcp_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Private_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Private_RT_Id% --destination-cidr-block 0.0.0.0/0 --nat-gateway-id %NATGW_Id% >tmpFile
aws ec2 associate-route-table  --subnet-id %pbsp1_Id% --route-table-id %Private_RT_Id% >tmpFile
aws ec2 associate-route-table  --subnet-id %pbsp2_Id% --route-table-id %Private_RT_Id% >tmpFile

rem Crear y aceptar el VPC Peering
aws ec2 create-vpc-peering-connection --vpc-id %vpcn_Id% --peer-vpc-id %vpcp_Id%|jq ".VpcPeeringConnection.VpcPeeringConnectionId" >tmpFile
set /p VPCPeering_Id= < tmpFile 
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id %VPCPeering_Id% >tmpFile
rem Agregar las rutas en las 2 tablas de ruteo
aws ec2 create-route --route-table-id %Private_RT_Id% --destination-cidr-block %vpcn_Mask% --vpc-peering-connection-id %VPCPeering_Id% >tmpFile
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block %vpcp_Mask% --vpc-peering-connection-id %VPCPeering_Id% >tmpFile


rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab6a --query "KeyMaterial" --output text > Lab6a.pem
winscp.com /keygen "Lab6a.pem" /output="Lab6a.ppk"

rem Crear los Security Groups para instancias A y B
aws ec2 create-security-group --group-name "SecGroup_AB" --description "Security group for Instances A and B" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_AB_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile


rem Crear los Security Groups para instancias C y D
aws ec2 create-security-group --group-name "SecGroup_CD" --description "Security group for Instances C and D" --vpc-id %vpcp_Id% |jq ".GroupId">tmpFile
set /p SecGroup_CD_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_CD_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_CD_Id% --protocol tcp --port 8080 --cidr 0.0.0.0/0 >tmpFile


rem AWS sugiere que se tome el AMI Amazon Linux 2 y se instale docker desde linea de comandos: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 

rem Se solicitan instancias y se adiciona un bootstrap para comprobar que el docker fue instalado
rem Se arrancan con las instancias de backend ya que es necesario modificar posteriormente la capa de presentacion con el nombre del balanceador
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_CD_Id% --subnet-id %pbsp1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=C}]"  --user-data file://bootstrapCD.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance3Id= <tmpFile
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_CD_Id% --subnet-id %pbsp2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=D}]"  --user-data file://bootstrapCD.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance4Id= <tmpFile

pause

rem ************** Seccion NLB  **************

rem Se hace el Balanceador Interno con NLB
rem Crear los Security Group del Balanceador
aws ec2 create-security-group --group-name "SecGroup_CDNLB" --description "Security group for NLB" --vpc-id %vpcp_Id% |jq ".GroupId">tmpFile
set /p SecGroup_CDNLB_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_CDNLB_Id% --protocol tcp --port 8080 --cidr 0.0.0.0/0 >tmpFile
rem Permitir que el balanceador pueda ver las instancias, sirve para el balanceo y el healthcheck
aws ec2 authorize-security-group-ingress --group-id %SecGroup_CD_Id% --protocol tcp --port 8080 --source-group %SecGroup_CDNLB_Id%  >tmpFile

rem Crear los target groups y registrar las instancias a los mismos en cada puerto
aws elbv2 create-target-group --name TG-Port-8080 --protocol TCP --port 8080 --target-type instance --vpc-id %vpcp_Id% |jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG8080_ARN= < tmpFile 
aws elbv2 register-targets --target-group-arn %TG8080_ARN% --targets Id=%Instance3Id% Id=%Instance4Id%

rem Crear el NLB
aws elbv2 create-load-balancer --name NLBLab6a --scheme internal --type network --subnets %pbsp1_Id% %pbsp2_Id%  >tmpFile2
type tmpFile2|jq ".LoadBalancers[].LoadBalancerArn" >tmpFile
set /p NLB_ARN= < tmpFile
type tmpFile2|jq ".LoadBalancers[].DNSName" >tmpFile
set /p NLB_DNSName= < tmpFile
del tmpFile2

rem Se crea el Listener para Puerto 8080
aws elbv2 create-listener --load-balancer-arn %NLB_ARN% --protocol TCP --port 8080 --default-actions Type=forward,TargetGroupArn=%TG8080_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST8080_ARN= < tmpFile

rem ************** Seccion ALB  **************
rem Se crean las instancias de la capa superiro modificando el bootstrap script para que tomen el balanceador interno
echo El nombre del balanceador interno es %NLB_DNSName%
pause
rem Antes de lanzarla se tiene que modificar el archivo bootrstrapAB.txt con el nombre del balanceador interno que esta en la variable %NLB_DNSName% agregarle el puerto 8080
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_AB_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]"  --user-data file://bootstrapAB.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance1Id= <tmpFile
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_AB_Id% --subnet-id %pbsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]"  --user-data file://bootstrapAB.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance2Id= <tmpFile

rem Crear los Security Group del Balanceador. Se agrega IPv6 como entrada al ALB
aws ec2 create-security-group --group-name "SecGroup_ABLB" --description "Security group for ALB" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_ABLB_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=0:0:0:0::/0}] >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile
rem Permitir que el balanceador pueda ver las instancias, sirve para el balanceo y el healthcheck
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 80 --source-group %SecGroup_ABLB_Id% >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 443 --source-group %SecGroup_ABLB_Id% >tmpFile


rem Crear los target groups y registrar las instancias a los mismos en cada puerto
aws elbv2 create-target-group --name TG-Port-80 --protocol HTTP --port 80 --target-type instance --vpc-id %vpcn_Id% |jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG80_ARN= < tmpFile 
aws elbv2 register-targets --target-group-arn %TG80_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%

rem Crear el ALB
aws elbv2 create-load-balancer --name ALBLab6a --subnets %pbsn1_Id% %pbsn2_Id% --security-groups %SecGroup_ABLB_Id% >tmpFile2
type tmpFile2|jq ".LoadBalancers[].LoadBalancerArn" >tmpFile
set /p LB_ARN= < tmpFile
type tmpFile2|jq ".LoadBalancers[].DNSName" >tmpFile
set /p LB_DNSName= < tmpFile
del tmpFile2

rem Se crea el Listener para Puerto 80
aws elbv2 create-listener --load-balancer-arn %LB_ARN% --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=%TG80_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST80_ARN= < tmpFile
rem Se prueba que el ALB llegue al target group desde un navegador despues de que el estado del ALB este en active 
aws elbv2 describe-load-balancers|jq ".LoadBalancers[] | .DNSName, .State.Code"
echo Para navegar a %LB_DNSName%

rem Opcional. Conocer la IP del Contenedor interna. Ingresar a las instancias publicas por su IP y conocer la IP interna del Docker
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <Nombre_Contenedor>

rem *********************** PLAY WITH HEALTHCHECK **********************
rem Modifica Health Check para NLB para deshabilitarlo o ponerlo en modo desconectado aleatoriamente
aws elbv2 modify-target-group --target-group-arn %TG80_ARN% --health-check-protocol HTTP --health-check-port 80 --health-check-path "/longdelay.py" >tmpFile
aws elbv2 describe-target-groups --target-group-arns %TG80_ARN%
rem Si ambos maquinas fallan, la documentacion dice que envia el paquete sin importar el estado asi que es mejor volver ir a una maquina A o B y detener el docker.
rem La documentacion esta en https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html y dice "If a target group contains only unhealthy registered targets, the load balancer routes requests to all those targets, regardless of their health status."
aws ec2 describe-instances --filters "Name=tag:Name,Values=A"  "Name=instance-state-name,Values=running"  |  jq -r  ".Reservations[] | .Instances[]|.PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 
putty -i "Lab6a.ppk" ec2-user@%A_IP%
rem Ir al putty
docker ps -a
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
rem Para hacer estas revisiones es mejor ejecutarlo con la siguiente configuracion del healthcheck:
rem Healthy threshold y Unhealthy threshold   2
rem Timeout 17s
rem Interval 20s
rem Revisar el balanceador que solo lo envie a la instancia correcta...luego lo volvemos a ejecutar la ultima linea del bootstrapAB.txt en el docker y vamos al docker y reemplazamos el index.py por longdelay.py
docker run -d -p 80:80 -p 443:443 -e APPSERVER="http://NLBLab6a-fb6ec9fe63257cf7.elb.us-east-1.amazonaws.com:8080" -e TZ=America/Bogota -h web1 fmorenod81/mtwa:web
docker exec -ti 680 sh
cd /var/www/html/appdemo
mv longdelay.py index.py
rem Alli comprobamos que la maquina funciona sin embargo esta deshabilitada en el balanceador
mv shortdelay.py index.py
rem Volvemos a ejecutar el balanceador y esperamos que se ejecute el healthy a la instancia
rem Salir del putty

rem Volver a la consola. Verificar accion sobre el estado del ALB. Aunque esto ya no aplica si vamos a ejecutarlo desde el balancador.
aws elbv2 modify-target-group --target-group-arn %TG80_ARN% --health-check-protocol HTTP --health-check-port 80 --health-check-path "/shortdelay.py"
aws elbv2 modify-target-group --target-group-arn %TG80_ARN% --health-check-protocol HTTP --health-check-port 80 --health-check-path "/"

rem ----- ELIMINAR RECURSOS ----
rem VPC: Peering Connections
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id %VPCPeering_Id%
rem EC2: Instances
aws ec2 terminate-instances --instance-ids %Instance1Id% %Instance2Id% >tmpFile
aws ec2 terminate-instances --instance-ids %Instance3Id% %Instance4Id% >tmpFile
rem EC2: Load LoadBalancers
aws elbv2 delete-load-balancer --load-balancer-arn %LB_ARN%
aws elbv2 delete-load-balancer --load-balancer-arn %NLB_ARN%
rem EC2: TargetGroups
aws elbv2 delete-target-group --target-group-arn %TG80_ARN%
aws elbv2 delete-target-group --target-group-arn %TG8080_ARN%
rem VPC: NAT gateway
aws ec2 delete-nat-gateway --nat-gateway-id %NATGW_Id%
rem EC2: Keypair
aws ec2 delete-key-pair --key-name Lab6b
del *.pem
del *.ppk
rem EC2: Security Group
aws ec2 delete-security-group --group-id %SecGroup_AB_Id%
aws ec2 delete-security-group --group-id %SecGroup_ABLB_Id%
aws ec2 delete-security-group --group-id %SecGroup_CD_Id% 
aws ec2 delete-security-group --group-id %SecGroup_CDNLB_Id% 
rem VPC: EIP - Esperar que el NAT GW se haya eliminado
aws ec2 release-address --allocation-id %NAT_EIP%
rem VPC: VPC
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 detach-internet-gateway --internet-gateway-id %IGW2_Id% --vpc-id %vpcp_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW2_Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-subnet --subnet-id %pbsn2_Id%
aws ec2 delete-subnet --subnet-id %pbsn3_Id%
aws ec2 delete-subnet --subnet-id %pbsp1_Id%
aws ec2 delete-subnet --subnet-id %pbsp2_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 delete-route-table --route-table-id %Private_RT_Id%
aws ec2 delete-route-table --route-table-id %Public_Private_RT_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%
aws ec2 delete-vpc --vpc-id %vpcp_Id%
