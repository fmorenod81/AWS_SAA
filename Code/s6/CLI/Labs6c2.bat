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
aws ec2 create-key-pair --key-name Lab6b --query "KeyMaterial" --output text > Lab6b.pem
winscp.com /keygen "Lab6b.pem" /output="Lab6b.ppk"

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
rem NO ES NECESARIO CREAR ESTAS INSTANCIAS NI REGISTRARLAS EN EL TARGET GROUP; YA QUE EL AUTOSCALING GROUP LO HACE AL TENER UN NUMERO DESEADO.
rem HASTA AQUI ES IGUAL A LO QUE HACEMOS EN EL LABORATORIO ANTERIOR 
rem aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_AB_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]"  --user-data file://bootstrapAB.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
rem set /p Instance1Id= <tmpFile
rem aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab6a --security-group-ids %SecGroup_AB_Id% --subnet-id %pbsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]"  --user-data file://bootstrapAB.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
rem set /p Instance2Id= <tmpFile

rem Crear los Security Group del Balanceador
aws ec2 create-security-group --group-name "SecGroup_ABLB" --description "Security group for ALB" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_ABLB_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile
rem Permitir que el balanceador pueda ver las instancias, sirve para el balanceo y el healthcheck. Se agrega IPv6 como entrada al ALB
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 80 --source-group %SecGroup_ABLB_Id% >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=0:0:0:0::/0}] >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_AB_Id% --protocol tcp --port 443 --source-group %SecGroup_ABLB_Id% >tmpFile


rem Crear los target groups y registrar las instancias a los mismos en cada puerto
aws elbv2 create-target-group --name TG-Port-80 --protocol HTTP --port 80 --target-type instance --vpc-id %vpcn_Id% |jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG80_ARN= < tmpFile 
rem NO ES NECESARIO CREAR ESTAS INSTANCIAS NI REGISTRARLAS EN EL TARGET GROUP; YA QUE EL AUTOSCALING GROUP LO HACE AL TENER UN NUMERO DESEADO.
rem aws elbv2 register-targets --target-group-arn %TG80_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%

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
rem Se prueba que el ALB llegue al target group desde un navegador despues de que el estado del ALB este en active.
rem aws elbv2 describe-load-balancers|jq ".LoadBalancers[] | .DNSName, .State.Code"
rem PORQUE NO FUNCIONA ? 
echo Para navegar a %LB_DNSName%


rem Se tiene que crear un Launch Template
rem Se crea una configuracion para la capa Web. SE TIENE
echo Se tiene que modificar bootstrapAB.txt con el nuevo nombre del balanceador interno es %NLB_DNSName%
aws autoscaling create-launch-configuration --launch-configuration-name LaunchCFG_For_Web --image-id %AMI% --instance-type %instance_type% --security-groups %SecGroup_AB_Id% --key-name Lab6b --user-data file://bootstrapAB.txt >tmpFile

rem Se tiene que crear un AutoScaling Group para un LB
aws autoscaling create-auto-scaling-group --auto-scaling-group-name ASG_For_Web --launch-configuration-name LaunchCFG_For_Web --vpc-zone-identifier %pbsn1_Id%,%pbsn2_Id% --target-group-arns %TG80_ARN% --max-size 5 --min-size 1 --desired-capacity 1 >tmpFile
rem Se crea un escalamiento simple en crecimiento y decreciendo. https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html#simple-scaling-policies-aws-cli
aws autoscaling put-scaling-policy --policy-name Lab6b-scale-out-policy --auto-scaling-group-name ASG_For_Web --scaling-adjustment 50 --adjustment-type PercentChangeInCapacity|jq ".PolicyARN" >tmpFile
set /p ASG_Scaleout_Policy= <tmpFile
aws autoscaling put-scaling-policy --policy-name Lab6b-scale-in-policy --auto-scaling-group-name ASG_For_Web --scaling-adjustment -1 --adjustment-type ChangeInCapacity --cooldown 180 |jq ".PolicyARN" >tmpFile
set /p ASG_Scalein_Policy= <tmpFile
aws cloudwatch put-metric-alarm --alarm-name Step-Scaling-AlarmHigh-AddCapacity  --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 60 --evaluation-periods 1 --threshold 60 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=ASG_For_Web" --alarm-actions %ASG_Scaleout_Policy% >tmpFile
aws cloudwatch put-metric-alarm --alarm-name Step-Scaling-AlarmLow-RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --evaluation-periods 1 --threshold 40 --comparison-operator LessThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=ASG_For_Web" --alarm-actions %ASG_Scalein_Policy% >tmpFile
rem Un par de minutos despues empieza a arrancar las instancias....verificar con la Consola Web

rem Vamos a estressar el sistema y verificar como suben las instancias https://buildvirtual.net/testing-aws-auto-scaling-policies-using-stress/ and https://gist.github.com/mikepfeiffer/d27f5c478bef92e8aff4241154b77e54
rem Reemplazar la IP Publica con la de las instancias Web o por medio del siguiente comando
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq "[.Reservations | .[] | .Instances | .[] | {InstanceId: .InstanceId, State: .State.Name, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags[]), PrivateIpAddress: .PrivateIpAddress, PublicIpAddress: .PublicIpAddress}]" 


pause 


putty -i "Lab6b.ppk" ec2-user@3.237.91.133
sudo amazon-linux-extras install epel -y
sudo yum install stress -y
rem Definir la cantidad de CPUs a cargar, esto depende del tipo de instancia a realizar la prueba. t3.small tiene 2 cpus
stress --cpu 4 --timeout 600 &
top
rem Se puede demorar un par de minutos para que el TG detecte la nueva instancia y active el healthcheck como correcto y asi continue. Se verifica con el ALB que este dando a la nuevas intanscias.
rem Se comprueba consumo por medio de llamadas
for /l %N in (1 1 20) do curl http://ALBLab6a-1702098729.us-east-1.elb.amazonaws.com/

rem ----- ELIMINAR RECURSOS ----
rem EC2: Delete instances manually and backend
aws ec2 terminate-instances --instance-ids %Instance3Id% %Instance4Id% >tmpFile
aws elbv2 delete-load-balancer --load-balancer-arn %NLB_ARN%
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id %VPCPeering_Id%

rem EC2: Auto Scaling Group
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ASG_For_Web --force-delete
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq "[.Reservations | .[] | .Instances | .[] | {InstanceId: .InstanceId, State: .State.Name, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags[]), PrivateIpAddress: .PrivateIpAddress, PublicIpAddress: .PublicIpAddress}]" 
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq "[.Reservations | .[] | .Instances | .[] | {InstanceId: .InstanceId, State: .State.Name}]" 
rem Se eliminan las instancias creadas por el ASG
aws ec2 terminate-instances --instance-id i-0405e73265cbaebea i-0c28c4a16662ee96c

rem EC2: Launch configurations
aws autoscaling delete-launch-configuration --launch-configuration-name LaunchCFG_For_Web

rem EC2: Load LoadBalancers - ALB
aws elbv2 delete-load-balancer --load-balancer-arn %LB_ARN%
rem EC2: Target Groups
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
aws ec2 delete-security-group --group-id %SecGroup_CD_Id% 
aws ec2 delete-security-group --group-id %SecGroup_CDNLB_Id% 
aws ec2 delete-security-group --group-id %SecGroup_ABLB_Id%

rem VPC: EIP
rem Es necesario esperar un rato para que el NAT Gateway se destruya
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
