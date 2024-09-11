rem Prerequisito tener el putty completo en el path
rem Infrastructura de Red e Instancias Publicas
rem Se van a crear 2 instancias publicas en una misma AZ y subnet. Sera necesario ingresar con Docker para ejecutar nombre diferentes y diferenciarlas.

rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Variables de configuracion
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"
set pbsn2_Mask="10.0.1.0/24"
set first_az="us-east-1a"
set second_az="us-east-1b"
set instance_type="t2.micro"

rem Crear la VPC y habilitar resolucion DNS
aws ec2 create-vpc --cidr-block %vpcn_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcn_Id% --enable-dns-hostnames "{\"Value\":true}"

rem Crear subred Publica 1
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch

rem Crear subred Publica 2
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn2_Mask% --availability-zone %second_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn2_Id= < tmpFile 
aws ec2 modify-subnet-attribute --subnet-id %pbsn2_Id% --map-public-ip-on-launch

rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile
set /p IGW_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcn_Id% --internet-gateway-id %IGW_Id%

rem Crear tabla de ruteo publica y asignarle IGW como ruta por defecto
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW_Id%

rem Asociar la tabla de ruta a las subreds
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id%
aws ec2 associate-route-table  --subnet-id %pbsn2_Id% --route-table-id %Public_RT_Id%

rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab10a --query "KeyMaterial" --output text > Lab10a.pem
winscp.com /keygen "Lab10a.pem" /output="Lab10a.ppk"

rem Crear los Security Groups para esa instancia
aws ec2 create-security-group --group-name "SecGroup_A" --description "Security group for Instance A" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_A_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0

rem En el laboratorio de EC2 Inicial se mostrar la importancia de buscar una AMI correcto. 
rem AWS sugiere que se tome el AMI Amazon Linux 2 y se instale docker desde linea de comandos: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 

rem Se solicitan instancias y se adiciona un bootstrap para comprobar que el docker fue instalado
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab10a --security-group-ids %SecGroup_A_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]"  --user-data file://bootstrapEUROPE.sh |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance1Id= <tmpFile
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab10a --security-group-ids %SecGroup_A_Id% --subnet-id %pbsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]"  --user-data file://bootstrapASIA.sh |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p Instance2Id= <tmpFile

rem Traer Datos especificos de instancia A. Revisar contenido describe-instances y Read_A.jq ya que es diferente a lo de anteriores laboratorios.
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq -f Read_A.jq|jq ".[0].PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq -f Read_B.jq|jq ".[0].PublicIpAddress" >tmpFile
set /p B_IP= < tmpFile 

rem ********************* SECTION ALB *******************************
rem Crear los Security Group del Balanceador
aws ec2 create-security-group --group-name "SecGroup_ABLB" --description "Security group for ALB" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_ABLB_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id %SecGroup_ABLB_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0
rem Crear los target groups y registrar las instancias a los mismos en cada puerto
aws elbv2 create-target-group --name TG-Port-80 --protocol HTTP --port 80 --target-type instance --vpc-id %vpcn_Id% |jq ".TargetGroups[].TargetGroupArn" >tmpFile
set /p TG80_ARN= < tmpFile 
rem Registrar las instancias
aws elbv2 register-targets --target-group-arn %TG80_ARN% --targets Id=%Instance1Id% Id=%Instance2Id%
rem Crear el ALB
aws elbv2 create-load-balancer --name ALBLab10b --subnets %pbsn1_Id% %pbsn2_Id% --security-groups %SecGroup_ABLB_Id% >tmpFile2
type tmpFile2|jq ".LoadBalancers[].LoadBalancerArn" >tmpFile
set /p LB_ARN= < tmpFile
type tmpFile2|jq ".LoadBalancers[].DNSName" >tmpFile
set /p LB_DNSName= < tmpFile
del tmpFile2

rem Se crea el Listener para Puerto 80
aws elbv2 create-listener --load-balancer-arn %LB_ARN% --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=%TG80_ARN%|jq ".Listeners[].ListenerArn" >tmpFile
set /p LST80_ARN= < tmpFile

rem Ahora si se crea el Certificado Digital y Luego, el listener usando ese certificado.


rem Se va al navegador y se visualizan con las IPs publicas los puertos 80


rem ----- ELIMINAR RECURSOS ----
rem Entiendo que despues de 12h se empieza a cobrar Route 53
rem Eliminar Route 53 Hosted Zone como primer paso
aws ec2 delete-key-pair --key-name Lab10a
aws ec2 terminate-instances --instance-ids %Instance1Id% %Instance2Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-security-group --group-id %SecGroup_A_Id%
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%


rem Opcional. Conocer la IP del Contenedor interna
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <Nombre_Contenedor>


