rem Modificado de https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html 

rem Prerequisito tener el putty completo en el path
rem Puede omitir un paso del KeyGen usando winscp en el path tambien.
rem Para este ultimo paso puede seguir la instrucciones de AWS en https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/putty.html
rem o usar winscp como se muestra en https://stackoverflow.com/questions/28042777/how-to-convert-pem-file-to-ppk-using-puttygen-in-ubuntu

rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=

rem Setear las variables
set vpcn_Mask="10.6.0.0/16"
set pbsn1_Mask="10.6.0.0/24"
set prsn2_Mask="10.6.1.0/24"
set first_az="us-east-1a"
set second_az="us-east-1b"

rem Crear la VPC 
aws ec2 create-vpc --cidr-block %vpcn_Mask% --tag-specification ResourceType=vpc,Tags=[{Key=Name,Value=Labs4VPC}] |jq ".Vpc.VpcId"  >tmpFile
set /p vpcn_Id= < tmpFile 

rem Crear subred Publica
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az% --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=Labs4VPCPublica}]|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 


rem Crear el Internet Gateway IGW y asignarlo a la VPC
aws ec2 create-internet-gateway|jq ".InternetGateway.InternetGatewayId"  >tmpFile
set /p IGW_Id= < tmpFile 
aws ec2 attach-internet-gateway --vpc-id %vpcn_Id% --internet-gateway-id %IGW_Id%

rem Crear tabla de ruteo publica y asignarle IGW como ruta por defecto
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Public_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Public_RT_Id% --destination-cidr-block 0.0.0.0/0 --gateway-id %IGW_Id%
rem Revisar Rutas de la Tabla de Ruteo
aws ec2 describe-route-tables --route-table-id %Public_RT_Id%

rem Asociar la tabla de ruta a la subred
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id%

rem Permitir que las instancias que se ejecutan en la subred se hagan publicas
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch

rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab4a --query "KeyMaterial" --output text > Lab4a.pem
rem Existe otra manera de cambiar de PPK a PEM: https://aws.amazon.com/premiumsupport/knowledge-center/convert-pem-file-into-ppk/
winscp.com /keygen "Lab4a.pem" /output="Lab4a.ppk"


rem Crear los Security Groups para esa instancia
aws ec2 create-security-group --group-name "SSHAccess" --description "Security group for SSH access" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SSH_Sec_Group_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0

rem En el laboratorio de EC2 Inicial se mostrar la importancia de buscar una AMI correcto.
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile

set /p AMI= < tmpFile 
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type t2.micro --key-name Lab4a --security-group-ids %SSH_Sec_Group_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]"
aws ec2 describe-instances --query "Reservations[*].Instances[*].[VpcId, InstanceId, ImageId, InstanceType, PublicIpAddress, PrivateIpAddress]"
rem La IP Publica de la instancia es 3.91.198.177
rem ---- SEGUNDA SUBRED -----------

rem Crear subred Privada
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %prsn2_Mask% --availability-zone %second_az% --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=Labs4VPCPrivada}]|jq ".Subnet.SubnetId" >tmpFile
set /p prsn2_Id= < tmpFile 

rem Solicitar una IP Elastica para hacer el Nat Gateway
aws ec2 allocate-address --domain vpc |jq ".AllocationId" >tmpFile
set /p NAT_EIP= < tmpFile 

rem Crear el NAT Gateway, asignarlo a una EIP Anterior.
aws ec2 create-nat-gateway --subnet-id  %pbsn1_Id% --allocation-id %NAT_EIP%|jq ".NatGateway.NatGatewayId" >tmpFile
set /p NATGW_Id= < tmpFile 

rem Crear tabla de ruteo para las redes privadas y asignar el NAT GW como ruta por defecto. Asociarla
aws ec2 create-route-table --vpc-id %vpcn_Id%|jq ".RouteTable.RouteTableId" >tmpFile
set /p Private_RT_Id= < tmpFile 
aws ec2 create-route --route-table-id %Private_RT_Id% --destination-cidr-block 0.0.0.0/0 --nat-gateway-id %NATGW_Id%
aws ec2 associate-route-table  --subnet-id %prsn2_Id% --route-table-id %Private_RT_Id%

rem Genera la segunda Instancia
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type t3.small --key-name Lab4a --security-group-ids %SSH_Sec_Group_Id% --subnet-id %prsn2_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=B}]"
rem Traer estados de la Instancias
aws ec2 describe-instances | jq "[.Reservations | .[] | .Instances | .[] | {InstanceId: .InstanceId, State: .State.Name, SubnetId: .SubnetId, VpcId: .VpcId, Name: (.Tags[]), PrivateIpAddress: .PrivateIpAddress, PublicIpAddress: .PublicIpAddress}]"
rem Traer Datos especificos de instancia A. Revisar contenido de Read_A.jq
aws ec2 describe-instances | jq -f Read_A.jq
aws ec2 describe-instances | jq -f Read_A.jq|jq ".[].PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 


rem Mirar en la consola como estan los Security Groups y verificar el de SSHAccess
rem Mirar en la consola como esta los NACLs por defecto https://console.aws.amazon.com/vpc/home?region=us-east-1#acls:sort=networkAclId

rem Enviar la llave a la Instancia Publica para luego desde alli conectarse a la IP Privada
psftp.exe -i "Lab4a.ppk" ec2-user@%A_IP%
rem Luego alli enviar el codigo para subir el certificado y salir
put Lab4a.pem
chmod 400 Lab4a.pem
exit

rem Ingresar a la instancia publica por SSH y dejar ejecutando en el SSH  "sudo python -m SimpleHTTPServer 80"
putty.exe -i "Lab4a.ppk" ec2-user@%A_IP%
rem Mirar la configuracion de la maquina actual
ip a
rem Conectarse por SSH a la Instancia Privada y desde alli escribir la IP de las instancias.
ssh -i "Lab4a.pem" ec2-user@10.6.1.23
rem Mirar la configuracion de la maquina actual y revisar conectividad
ip a
ping 8.8.8.8
exit


rem Dentro de la instancia publica ejecutar
sudo python -m SimpleHTTPServer 80

rem Intentar ingresar por un navegador a esa IP Publica
rem Modificar el Security Group para habilitar el puerto 80
aws ec2 authorize-security-group-ingress --group-id %SSH_Sec_Group_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0
rem Volver a intentar ingresar por un navegador a esas IP's

rem Eliminar el ingreso del Security Group anterior
aws ec2 revoke-security-group-ingress --group-id %SSH_Sec_Group_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0
rem Volver a intentar ingresar por un navegador a esas IP's


rem ----- ELIMINAR RECURSOS ----
aws ec2 terminate-instances --instance-ids "i-0c06517589ed3ca8b" "i-0971c94f478245a14"
rem Algunas veces toca esperar que las instancias esten borradas
aws ec2 delete-security-group --group-id %SSH_Sec_Group_Id%
aws ec2 delete-subnet --subnet-id %prsn2_Id%
aws ec2 delete-nat-gateway --nat-gateway-id %NATGW_Id%
aws ec2 delete-route-table --route-table-id %Private_RT_Id%
rem Algunas veces toca esperar que el NAT Gateway sea borrado exitosamente
aws ec2 release-address --allocation-id %NAT_EIP%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%
aws ec2 delete-key-pair --key-name Lab4a
del Lab4a.pem
del Lab4a.ppk
del tmpFile