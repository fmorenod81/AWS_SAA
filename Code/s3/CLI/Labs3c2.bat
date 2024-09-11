
rem **********************************************************************
rem LAB 3B: Replication en 2 regiones de la misma cuenta
rem **********************************************************************


rem Primero ingresar los datos de configuracion de la cuenta, obtenidos del archivo csv del IAM
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Definicion de nombres que sea DNS-Compliant Name
set SourceBucket=www.ocidemo1281.original
set DestinationBucket=www.ocidemo1281.replicado

rem Creacion de buckets y que tenga el versionamiento habilitados en ambos
aws s3api create-bucket --bucket %SourceBucket% --region us-east-1 
aws s3api put-bucket-versioning --bucket %SourceBucket% --versioning-configuration Status=Enabled
aws s3api create-bucket --bucket %DestinationBucket% --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-bucket-versioning --bucket %DestinationBucket% --versioning-configuration Status=Enabled

rem Crear un rol que tenga un alcance/Trusted Entity al servicio s3; y aplicar un rol que permite leer, escribir y duplicar en los buckets
aws iam create-role --role-name replicationRole --assume-role-policy-document file://S3-role-trust-policy.json 
rem Copiar el ARN del Rol que se genero
rem Modificar el documento de permisos por rol para añadir el nombre de los 2 buckets 
aws iam put-role-policy --role-name replicationRole --policy-document file://S3-role-permissions-policy.json --policy-name replicationRolePolicy

rem Modificar el archivo de replication.json que permite la replicacion por medio de la configuracion del bucket
rem Aplicar el Role ARN; y el nombre del bucket destino
rem El ejemplo de AWS se puede colocar filtros al archivo json https://docs.aws.amazon.com/AmazonS3/latest/dev/replication-walkthrough1.html
aws s3api put-bucket-replication --replication-configuration file://replication.json --bucket %SourceBucket%

rem Revisar configuracion
aws s3api get-bucket-replication --bucket %SourceBucket%

rem Realizar la prueba en AWS Web Management Console creando una carpeta llamada Tax y enviando archivos alli.
rem Seleccionar el bucket replicado y revisando las propiedades del archivo creado
rem Puede revisar y saber que tipo de politica se esta aplicando al role de replica ya sea por linea de comando o por Web Management Console

rem Desocupar los buckets
aws s3api delete-bucket --bucket %SourceBucket% --region us-east-1 
aws s3api delete-bucket --bucket %DestinationBucket% --region ap-south-1
aws iam delete-role-policy --role-name replicationRole --policy-name replicationRolePolicy
aws iam delete-role --role-name replicationRole
