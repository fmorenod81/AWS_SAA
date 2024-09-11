rem Prerequisito tener el putty completo en el path
rem Tener un convertidor de base64 en Windows ya esta y se llama certutil en otro caso, buscar en Web o MacOs openssl base64 -in <infile> -out <outfile>


rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Antes de iniciar el laboratorio se debe comprobar la cantidad de vCPUs que se pueden ejecutar en Spot Instances:
aws service-quotas get-service-quota --service-code ec2 --quota-code L-34B43A08|jq ".Quota.Value" 

rem Setear las variables de su grupo. Clase A: 10.x.x.x/8 Clase B: 172.16.x.x a 172.31.x.x
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"
set first_az="us-east-1a"
set instance_type="t2.micro"

rem Crear la VPC y habilitar resolucion DNS
aws ec2 create-vpc --cidr-block %vpcn_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcn_Id% --enable-dns-hostnames "{\"Value\":true}" >tmpFile

rem Crear subred Publica 
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 

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
aws ec2 create-key-pair --key-name Lab5a --query "KeyMaterial" --output text > Lab5a.pem
winscp.com /keygen "Lab5a.pem" /output="Lab5a.ppk"

rem Crear los Security Groups para esa instancia
aws ec2 create-security-group --group-name "SecGroup_A" --description "Security group for Instance A" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_A_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 443 --cidr 0.0.0.0/0 >tmpFile


rem En el laboratorio de EC2 Inicial se mostrar la importancia de buscar una AMI correcto. 
rem AWS sugiere que se tome el AMI Amazon Linux 2 y se instale docker desde linea de comandos: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html#install_docker
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 

rem Vamos a buscar un valor establecido para la subasta de la instancia
aws ec2 describe-spot-price-history --instance-types %instance_type% --product-description "Linux/UNIX (Amazon VPC)" --start-time 2024-07-29T07:08:09 --end-time 2024-07-29T08:09:10
aws ec2 describe-spot-price-history --instance-types %instance_type% --product-description "Linux/UNIX (Amazon VPC)" --start-time 2024-07-01T07:08:09 --end-time 2024-07-01T08:09:10|jq ".SpotPriceHistory[].SpotPrice"
aws ec2 describe-spot-price-history --instance-types %instance_type% --product-description "Linux/UNIX (Amazon VPC)" --start-time 2024-07-01T07:08:09 --end-time 2024-07-01T08:09:10|jq ".SpotPriceHistory[] | .SpotPrice, .AvailabilityZone"
rem Despues de mirar valor se va a ser solicitud de una sola vez. Se podria hacerse persistente, y estado de solicitudes en https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-requests.html
rem Recuerde que antes de lanzar este comando se tiene que modificar con el AMI, el Security Group, subred en pbsn1_Id y el bootstrap script (user data) en base 64 (usar certutil -encode bootstrap.sh bootstrapb64.sh en Windows)
rem Si el precio de la apuesta es muy bajo no alcanza a competir y no se ejecuta, por eso es importante revisar el estado del request
rem Se tiene que cambiar los valores de AMI, Subnet, Security Group dentro del archivo config.json
echo La informacion para modificar el archivo config.json son AMI "%AMI%" Sec Group %SecGroup_A_Id% Subnet %pbsn1_Id% 
certutil -f -encode bootstrap.sh tmp.b64 && findstr /v /c:- tmp.b64 > bootstrapb64.sh
del tmp.b64
echo Se toma el archivo bootstrap64.sh y se pone en una sola linea para ponerla en el config.json en la linea UserData. Se actualiza el precio para mirar su estado

rem Comparar que dato se envian del JSON a la linea de comando como se ve aqui y mirar la comparativa de precios
aws ec2 request-spot-instances --spot-price "0.004" --instance-count 1 --type "one-time" --launch-specification file://config.json
rem Revisar cuales son las instancias ejecutandose. Puedes modificar el ultimo jq con la instancia no null ".[1].ID" o la que no este vacia. Ese valor puede variar con las pruebas realizadas con los precios
aws ec2 describe-spot-instance-requests --query "SpotInstanceRequests[*].{ID:InstanceId}"|jq ".[0].ID">tmpFile
set /p InstanceId= <tmpFile

rem Create ENI y asignarla asociarla a la Instancia. Tambien se puede haber creado en la solicitud del Spot
aws ec2 create-network-interface --subnet-id %pbsn1_Id% --description "Additional Network Interface Instance A" --groups %SecGroup_A_Id%|jq ".NetworkInterface.NetworkInterfaceId">tmpFile
set /p ENI_Id= < tmpFile 
aws ec2 attach-network-interface --network-interface-id %ENI_Id% --instance-id %InstanceId% --device-index 1 >tmpFile

rem Obtener una EIP para asignarla a la ENI, se puede asociar directamente a la instancia
aws ec2 allocate-address --domain vpc |jq ".AllocationId" >tmpFile
set /p EIP_for_EC2= < tmpFile 
aws ec2 associate-address --allocation-id %EIP_for_EC2% --network-interface-id %ENI_Id% >tmpFile


rem Traer Datos especificos de instancia A. Revisar contenido describe-instances y Read_A.jq ya que es diferente a lo de anteriores laboratorios.
rem Para traer la ENI Ip Address quizas tenga que cambiar el indice de [1] o a algun valor no nulo, por eso se envia el primer comando.
aws ec2 describe-instances | jq -f Read_Spot.jq
aws ec2 describe-instances | jq -f Read_Spot.jq|jq ".[].ENIPublicIpAddress"
rem En este caso del listado anterior tomamos el valor de 3 que no entregaba una IP Publica
aws ec2 describe-instances | jq -f Read_Spot.jq|jq ".[3].ENIPublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 

rem Ingresar a la instancia publica por SSH, desde Web se toma la IP publica
putty.exe -i "Lab5a.ppk" ec2-user@%A_IP%
ping 8.8.8.8
rem Debido a que no generamos la ruta por defecto en la otra interface no permite conectarse a Internet. Puede ser route
route -n
sudo route del -net 0.0.0.0 gw 10.0.0.1 netmask 0.0.0.0 dev eth0
rem Comprobamos que la ruta fue borrada
route -n
ping 8.8.8.8
rem Ejecutar la instalacion de Docker
docker ps -a
cat /home/ec2-user/DesdeBootstrap.txt
rem Mirar porque no se ejecutar el Docker por medio de los archivos de logs en /var/log/cloud-init.log o /var/log/cloud-init-output.log
rem Adicionalmente mirar los archivos de /etc/cloud
rem Explicar el proceso que se inicia llamado cloudinit
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo docker ps -a
rem Extraemos algunos valores como Zona de Disponibilidad y la IP Publica
sudo docker run -d -p 80:80 -p 443:443 -h web1 fmorenod81/mtwa:web 
rem Ir al navegador y verificar funcionalidad. El siguiente comando sale en el computador local solamente
echo Ir al navegador a la pagina http://%A_IP%
sudo docker stop $(sudo docker ps -aq)
rem Se puede usar tambien un hello world como imagen en vez del anterior

export AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
sudo docker run -d -p 80:80 -h $HOSTNAME -e NAME=$AZ dockercloud/hello-world



rem ----- ELIMINAR RECURSOS ----
aws ec2 terminate-instances --instance-ids %InstanceId%
aws ec2 disassociate-address --public-ip %A_IP%
aws ec2 release-address --allocation-id %EIP_for_EC2%
rem Esperar hasta que la instancia termina
aws ec2 delete-network-interface --network-interface-id %ENI_Id%
aws ec2 delete-security-group --group-id %SecGroup_A_Id%
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%
aws ec2 delete-key-pair --key-name Lab5a
del Lab5a.pem
del Lab5a.ppk
del tmpFile