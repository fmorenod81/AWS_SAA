rem Modificado de https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html 

rem Prerequisito tener el putty completo en el path
rem Puede omitir un paso del KeyGen usando winscp en el path tambien.
rem Para este ultimo paso puede seguir la instrucciones de AWS en https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/putty.html
rem o usar winscp como se muestra en https://stackoverflow.com/questions/28042777/how-to-convert-pem-file-to-ppk-using-puttygen-in-ubuntu

rem Clave del usuario
#set AWS_ACCESS_KEY_ID=
#set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Setear las variables
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"

set vpcp_Mask="172.16.0.0/16"
set prsn2_Mask="172.16.0.0/24"
set first_az="us-east-1a"


rem Crear las VPC 
aws ec2 create-vpc --cidr-block %vpcn_Mask% --tag-specification ResourceType=vpc,Tags=[{Key=Name,Value=Labs4vpcn}]|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 create-vpc --cidr-block %vpcp_Mask% --tag-specification ResourceType=vpc,Tags=[{Key=Name,Value=Labs4vpcp}]|jq ".Vpc.VpcId" >tmpFile
set /p vpcp_Id= < tmpFile 

rem Crear y aceptar el VPC Peering
aws ec2 create-vpc-peering-connection --vpc-id %vpcn_Id% --peer-vpc-id %vpcp_Id%|jq ".VpcPeeringConnection.VpcPeeringConnectionId" >tmpFile
set /p VPCPeering_Id= < tmpFile 
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id %VPCPeering_Id% >tmpFile


rem Crear subredes
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az% --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=Lasbs4vpcn1}]|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 
aws ec2 create-subnet --vpc-id %vpcp_Id% --cidr-block %prsn2_Mask% --availability-zone %first_az% --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=Lasbs4vpcp1}]|jq ".Subnet.SubnetId" >tmpFile
set /p prsn2_Id= < tmpFile 

rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile
set /p IGW_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcn_Id% --internet-gateway-id %IGW_Id% >tmpFile

rem Crear tabla de ruteo publica, asignar ruta para el VPC Peering y asignarle IGW como ruta por defecto
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block %prsn2_Mask% --vpc-peering-connection-id %VPCPeering_Id% >tmpFile
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW_Id% >tmpFile
rem Asociar la tabla de ruta a la subred
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id% >tmpFile
rem Permitir que las instancias que se ejecutan en la subred se hagan publicas
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch >tmpFile

rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab4b --query "KeyMaterial" --output text > Lab4b.pem
winscp.com /keygen "Lab4b.pem" /output="Lab4b.ppk"

rem Crear los Security Groups para esas instancias
aws ec2 create-security-group --group-name "SecGrp VPC Public" --description "Security group for Instance A" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SSH_Sec_Group_n_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_n_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_n_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile

aws ec2 create-security-group --group-name "SecGrp VPC Private" --description "Security group for Instance B" --vpc-id %vpcp_Id% |jq ".GroupId">tmpFile 
set /p SSH_Sec_Group_p_Id= < tmpFile 
rem aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_p_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_p_Id% --protocol tcp --port 22 --cidr %pbsn1_Mask% >tmpFile


rem Crear tabla de ruteo para la red privada, asignar la tabla de la VPC Peering y asignar el NAT GW como ruta por defecto. 
aws ec2 create-route-table --vpc-id %vpcp_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Private_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Private_RT_Id% --destination-cidr-block %pbsn1_Mask% --vpc-peering-connection-id %VPCPeering_Id% >tmpFile
aws ec2 associate-route-table  --subnet-id %prsn2_Id% --route-table-id %Private_RT_Id% >tmpFile

rem Crear S3 VPC Endpoint 
aws ec2 create-vpc-endpoint --vpc-id %vpcp_Id% --service-name com.amazonaws.%AWS_DEFAULT_REGION%.s3 --route-table-ids %Private_RT_Id%|jq ".VpcEndpoint.VpcEndpointId" >tmpFile
set /p VPCEndpoint_Id= < tmpFile 
rem Crear instancias
aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type t3.micro --key-name Lab4b --security-group-ids %SSH_Sec_Group_n_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]" >tmpFile
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type t3.micro --key-name Lab4b --security-group-ids %SSH_Sec_Group_p_Id% --subnet-id %prsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]" >tmpFile




rem -------------------- MIRAR ESTADO ------------------------

rem Traer estados de la Instancias
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq "[.Reservations | .[] | .Instances | .[] | {InstanceId: .InstanceId, State: .State.Name, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags[]), PrivateIpAddress: .PrivateIpAddress, PublicIpAddress: .PublicIpAddress}]"  >tmpFile
rem Traer Datos especificos de instancia A. Revisar contenido de Read_A.jq
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq -f Read_A.jq|jq ".[].PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 

pause 

rem Enviar la llave a la Instancia Publica para luego desde alli conectarse a la IP Privada
psftp.exe -i "Lab4b.ppk" ec2-user@%A_IP%
rem Luego alli enviar el codigo para subir el certificado y salir
put Lab4b.pem
chmod 400 Lab4b.pem
exit

rem Ingresar a la instancia publica por SSH y dejar ejecutando en el SSH  "sudo python -m SimpleHTTPServer 80"
putty.exe -i "Lab4b.ppk" ec2-user@%A_IP%
rem Mirar la configuracion de la maquina actual
ip a
rem Mirar los saltos hacia s3
sudo traceroute -T -p 443 s3.us-east-1.amazonaws.com
rem Ejecutar para dejar un servidor web ejecutandose - Para Python 2 en Amazon Linux 2
sudo python -m SimpleHTTPServer 80 &
rem Ejecutar para dejar un servidor web ejecutandose - Para Python 3 en Amazon Linux 2023
sudo python3 -m http.server 80 &
rem Conectarse por SSH a la Instancia Privada y desde alli escribir la IP de la instancia privada
ssh -i "Lab4b.pem" ec2-user@172.16.0.215
rem Mirar la configuracion de la maquina actual y revisar conectividad
ip a
ping 8.8.8.8
sudo traceroute -T -p 443 s3.us-east-1.amazonaws.com

rem Verificar acceso a la IP Privada de la Instancia Publica.
curl 10.0.0.38

rem ----- ELIMINAR RECURSOS ----
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq -f Read_A.jq|jq ".[0].InstanceId" >tmpFile
set /p InstanceA= < tmpFile 
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq -f Read_B.jq|jq ".[0].InstanceId" >tmpFile
set /p InstanceB= < tmpFile 
aws ec2 terminate-instances --instance-ids %InstanceA% %InstanceB%
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id %VPCPeering_Id%
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids %VPCEndpoint_Id%
aws ec2 delete-security-group --group-id %SSH_Sec_Group_p_Id%
aws ec2 delete-security-group --group-id %SSH_Sec_Group_n_Id%
aws ec2 delete-subnet --subnet-id %prsn2_Id%
aws ec2 delete-route-table --route-table-id %Private_RT_Id%

aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%

aws ec2 delete-vpc --vpc-id %vpcp_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%

aws ec2 delete-key-pair --key-name Lab4b
del Lab4b.pem
del Lab4b.ppk
del tmpFile