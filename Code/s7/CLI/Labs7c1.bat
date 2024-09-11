rem Prerequisito tener el putty completo en el path

rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Estos pasos se pueden hacer usando la consola como se ha visto en clases y laboratorios pasados.
rem Se tienen que crear 2 zonas de disponibilidad para poner disponer de la Read Replica alli.
rem Adicionalmente se tiene que crear un Security Group para el RDS que tenga como origen el Security Group que se dispone para el servidor

rem Setear las variables de su grupo. Clase A: 10.x.x.x/8 Clase B: 172.16.x.x a 172.31.x.x
set vpcn_Mask="10.0.0.0/16"
set pbsn1_Mask="10.0.0.0/24"
set pbsn2_Mask="10.0.1.0/24"
set instance_type="t3.micro"
set first_az="us-east-1a"
set second_az="us-east-1b"

rem Crear la VPC y habilitar resolucion DNS
aws ec2 create-vpc --cidr-block %vpcn_Mask%|jq ".Vpc.VpcId" >tmpFile
set /p vpcn_Id= < tmpFile 
aws ec2 modify-vpc-attribute --vpc-id %vpcn_Id% --enable-dns-hostnames "{\"Value\":true}"

rem Crear subred Publica 
aws ec2 create-subnet --vpc-id %vpcn_Id% --cidr-block %pbsn1_Mask% --availability-zone %first_az%|jq ".Subnet.SubnetId" >tmpFile
set /p pbsn1_Id= < tmpFile 
aws ec2 modify-subnet-attribute --subnet-id %pbsn1_Id% --map-public-ip-on-launch
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

rem Asociar la tabla de ruta a la subred
aws ec2 associate-route-table  --subnet-id %pbsn1_Id% --route-table-id %Public_RT_Id%
aws ec2 associate-route-table  --subnet-id %pbsn2_Id% --route-table-id %Public_RT_Id%

rem Crear las llaves para el SSH a las nuevas instancias y convertirlas a PPK para usar Putty ya sea con puttygen o winscp
aws ec2 create-key-pair --key-name Lab7a --query "KeyMaterial" --output text > Lab7a.pem
winscp.com /keygen "Lab7a.pem" /output="Lab7a.ppk"

rem Crear los Security Groups para esa instancia
aws ec2 create-security-group --group-name "SecGroup_A" --description "Security group for Instance A" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_A_Id= < tmpFile 
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 22 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 80 --cidr 0.0.0.0/0 >tmpFile
aws ec2 authorize-security-group-ingress --group-id %SecGroup_A_Id% --protocol tcp --port 8080 --cidr 0.0.0.0/0 >tmpFile

rem Crear los Security Groups para esa RDS
aws ec2 create-security-group --group-name "SecGroup_RDS" --description "Security group for RDS" --vpc-id %vpcn_Id% |jq ".GroupId">tmpFile
set /p SecGroup_RDS_Id= < tmpFile 
rem Si quieres hacerla privada solamente tener la grupo con el source group
rem aws ec2 authorize-security-group-ingress --group-id %SecGroup_RDS_Id% --protocol tcp --port 3306 --source-group %SecGroup_A_Id%
aws ec2 authorize-security-group-ingress --group-id %SecGroup_RDS_Id% --protocol tcp --port 3306 --cidr 0.0.0.0/0 >tmpFile


rem Crear el Db Subnet Group y luego, el RDS MySQL. 

rem Se crea la Subnet Group agregando los nombre de las 2 Subredes. 
rem Estos comando genera mas info!!
aws rds create-db-subnet-group --db-subnet-group-name lab7dbgr --db-subnet-group-description lab7dbgr --subnet-ids %pbsn1_Id% %pbsn2_Id%
aws rds create-db-instance --db-name appdemo --db-instance-identifier appdemo --allocated-storage 10 --db-instance-class db.t3.micro --engine mysql --master-username appdemo --master-user-password appdemo1 --vpc-security-group-ids %SecGroup_RDS_Id% --availability-zone "us-east-1a" --no-multi-az --db-subnet-group-name lab7dbgr --publicly-accessible --no-enable-performance-insights --no-deletion-protection --backup-retention-period 1
rem Se tiene que esperar a que la RDS permanzca en estado Active para proseguir con el laboratorio. No es tan rapido hacer los cambios o las ejecuciones en las instancias BD.
aws rds describe-db-instances | jq "[.DBInstances| .[]|{DBInstanceIdentifier: .DBInstanceIdentifier, Engine, DBInstanceStatus, DBName, MasterUsername}]"
echo Se espera hasta que el estado sea Available
aws rds describe-db-instances | jq "[.DBInstances| .[]|.Endpoint|{Endpoint: .Address, Port}]"


rem Se autoselecciona el ultimo AMI para la instancia publica.
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text >tmpFile
set /p AMI= < tmpFile 
rem Se solicitan instancias y se adiciona un bootstrap para comprobar que el docker fue instalado, se inicia el docker del Frontend
aws ec2 run-instances --image-id %AMI% --count 1 --instance-type %instance_type% --key-name Lab7a --security-group-ids %SecGroup_A_Id% --subnet-id %pbsn1_Id% --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=A}]"  --user-data file://bootstrap.txt |jq "[.Instances|.[].InstanceId|.]"|jq ".[0]" >tmpFile
set /p InstanceId= <tmpFile

rem Traer Datos especificos de instancia A. Revisar el indice del utimo jq si tiene mas instancia ejecutando
aws ec2 describe-instances | jq -f Read_A.jq|jq ".[0].PublicIpAddress" >tmpFile
set /p A_IP= < tmpFile 
echo "Probar docker en %A_IP%"

rem Ingresar a la instancia publica por SSH, desde Web se toma la IP publica. Obtener la informacion del Endpoint
rem Esperar al menos por 3 minutos, mientras se generan los usuarios dentro de la instancia
rem Si se genera por CloudFormation es importante crearlo por asi
rem set A_IP="3.238.149.215"
putty.exe -i "Lab7a.ppk" ec2-user@%A_IP%
ping 8.8.8.8
rem Comprobar que el cloud init haya instalado el mysql, revisando el /var/log/cloud-init-output.log
rem revisar ejecutando el mysql sino podria
sudo yum install -y mysql 
rem deberia ser algo sencillo como
rem Si no funciona la instalacion del mysql
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
sudo yum install -y mysql-community-client

rem Reeemplazar el nombre del endpoint. La clave del usuario es appdemo1
mysql -h appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com -P 3306 -u appdemo -p


rem Copiar esta sentencia SQL  para la creacion de la base de datos. Verificar la ejecucion de los comandos que dicen Query Ok. En el create user puede que funcione o no.
CREATE DATABASE `appdemo`;
  USE `appdemo`;
  CREATE TABLE `demodata` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100),
  `notes` TEXT,
  `timestamp` TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY (`name`)
  );

  CREATE TABLE `demodata_erase_log` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `timestamp` TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY (`timestamp`));
CREATE USER 'appdemo'@'%' IDENTIFIED BY 'appdemo1';
GRANT ALL PRIVILEGES ON appdemo.* to 'appdemo'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
quit

rem Volviendo al PC. Crear el nuevo docker con el contenedor de la capa App. Para la variable DBSERVER_W asignar el endpoint de la base de datos para escritura y para DBSERVER_RO el de lectura
aws rds describe-db-instances | jq "[.DBInstances| .[]|{DBInstanceIdentifier: .DBInstanceIdentifier, Engine, DBInstanceStatus, DBName, MasterUsername, AvailabilityZone, Endpoint: .Endpoint.Address, Port: .Endpoint.Port}]"
echo Se reemplaza en las variables a enviar al Docker DBSERVER_W y DBSERVER_RO
docker run -d -p 8080:8080 -e TZ=America/Bogota -e DBSERVER_W="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -e DBSERVER_RO="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -h app1 fmorenod81/mtwa:app
rem Se cargan datos de prueba desde la pagina Web

rem Si se desean detener todos los contenedores y volver a iniciarlos, desde putty se ejecuta
docker stop $(docker ps -aq)
docker rm --force $(docker ps -aq)
export PUBLICIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
docker run -d -p 80:80 -p 443:443 -e APPSERVER=http://$PUBLICIP:8080 -e TZ=America/Bogota  -h web1 fmorenod81/mtwa:web --name frontend
docker run -d -p 8080:8080 -e TZ=America/Bogota -e DBSERVER_W="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -e DBSERVER_RO="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -h app1 fmorenod81/mtwa:app  --name backend
rem Algunas veces presentan problemas al iniciarlo y despues de un par de minutos funciona mejor o despues de un borrado
docker logs -f --until=30s backend

rem se crea una read replica
rem Si viene de Cloudformation. Se tiene que obtener este valor manualmente
set SecGroup_RDS_Id="sg-01118f81d277391a3"
aws rds create-db-instance-read-replica  --db-instance-identifier Read-Replica-RDS-Lab7a --source-db-instance-identifier appdemo --db-instance-class db.t3.micro  --vpc-security-group-ids %SecGroup_RDS_Id% --availability-zone "us-east-1a" --publicly-accessible --no-enable-performance-insights --no-deletion-protection

aws rds describe-db-instances | jq "[.DBInstances| .[]|select (.DBInstanceIdentifier|contains(\"read-replica-rds-lab7a\"))|{ DBInstanceIdentifier: .DBInstanceIdentifier, Engine, DBInstanceStatus, DBName, MasterUsername, AvailabilityZone, Endpoint: .Endpoint.Address, Port: .Endpoint.Port}]"
rem En Putty, detener el contenedor de capa App y volver a asignar las variables de entorno DBSERVER_W y DBSERVER_RO
docker ps -a | grep app|awk '{print $NF}'
docker stop <Contenedor_de_capa_APP>
docker rm --force <Contenedor_de_capa_APP>
docker ps -a
docker run -d -p 8080:8080 -e TZ=America/Bogota -e DBSERVER_W="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -e DBSERVER_RO="read-replica-rds-lab7a.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -h app1 fmorenod81/mtwa:app 

rem Que pasa cuando inviertes las variables, envia soporte del cambio. Opcional
docker ps -a | grep app|awk '{print $NF}'
docker stop fervent_ganguly
docker rm --force fervent_ganguly
docker ps -a
docker run -d -p 8080:8080 -e TZ=America/Bogota -e DBSERVER_W="read-replica-rds-lab7a.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -e DBSERVER_RO="appdemo.cl8d5lhujhwy.us-east-1.rds.amazonaws.com" -h app1 fmorenod81/mtwa:app 

REM ELIMINAR
RDS: Read Replica
rem RDS
aws rds delete-db-instance --db-instance-identifier Read-Replica-RDS-Lab7a --skip-final-snapshot
aws rds delete-db-instance --db-instance-identifier appdemo --skip-final-snapshot
rem Toca esperar hasta que se borren para lanzar el borrado de grupo, se siguen con los siguientes comandos
aws rds describe-db-instances | jq "[.DBInstances| .[]|select (.DBInstanceIdentifier|contains(\"read-replica-rds-lab7a\"))|{ DBInstanceIdentifier: .DBInstanceIdentifier, DBInstanceStatus, DBName}]"
aws rds describe-db-instances | jq "[.DBInstances| .[]|select (.DBInstanceIdentifier|contains(\"appdemo\"))|{ DBInstanceIdentifier: .DBInstanceIdentifier, DBInstanceStatus, DBName}]"
aws rds delete-db-subnet-group --db-subnet-group-name lab7dbgr
rem continuar aqui
aws ec2 terminate-instances --instance-ids %InstanceId%
aws ec2 delete-key-pair --key-name Lab7a
aws ec2 detach-internet-gateway --internet-gateway-id %IGW_Id% --vpc-id %vpcn_Id%
aws ec2 delete-internet-gateway --internet-gateway-id %IGW_Id%
aws ec2 delete-subnet --subnet-id %pbsn1_Id%
rem Esperar que se elimine la instancia
aws ec2 delete-security-group --group-id %SecGroup_A_Id%
aws ec2 delete-security-group --group-id %SecGroup_RDS_Id% 
rem Algunas veces molesta...borrar estos 2 pasos manualmente.
aws ec2 delete-subnet --subnet-id %pbsn2_Id%
aws ec2 delete-route-table --route-table-id %Public_RT_Id%
aws ec2 delete-vpc --vpc-id %vpcn_Id%
del Lab7a.pem
del Lab7a.ppk
del tmpFile