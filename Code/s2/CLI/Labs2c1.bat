rem Adaptado de https://aws.amazon.com/premiumsupport/knowledge-center/iam-assume-role-cli/
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Crear un grupo
aws iam create-group --group-name Dev
rem Crear los usuarios
aws iam create-user --user-name Bob
rem Agregar usuarios al grupo
aws iam  add-user-to-group --group-name Dev --user-name Bob
aws iam list-groups-for-user --user-name Bob
rem Crear la politica
aws iam create-policy --policy-name example-policy --policy-document file://example-policy.json
rem Asignar la politica al grupo, reemplazando el Account Number
aws iam attach-group-policy --group-name Dev --policy-arn "arn:aws:iam::768312754627:policy/example-policy"
rem Revisar que el listado de politicas asignadas al usuario
aws iam list-attached-group-policies --group-name Dev
aws iam list-group-policies --group-name Dev
aws iam list-attached-user-policies --user-name Bob
aws iam list-policies --scope Local

rem Crear un Role y asignarle un Trust Policy modificando el nombre de la cuenta debido a que puede ser diferente
aws iam create-role --role-name example-role --assume-role-policy-document file://example-role-trust-policy.json
rem Agregar una politica manejada por AWS al role
aws iam attach-role-policy --role-name example-role --policy-arn "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
rem Verificar listado de politicas asociadas al role
aws iam list-attached-role-policies --role-name example-role

rem Crear llaves de acceso al usuario
aws iam create-access-key --user-name Bob > LlavesBob.txt
rem Setear las variables de Entorno con la informacion de LlavesBob.txt
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Revisar que se esten ejecutando como Bob
aws sts get-caller-identity
rem Revisar que acciones puedo realizar como Bob. Falla con RDS
aws ec2 describe-instances --query "Reservations[*].Instances[*].[VpcId, InstanceId, ImageId, InstanceType]"
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier, DBName, DBInstanceStatus, AvailabilityZone, DBInstanceClass]"
rem Obtener el ARN del rol a aplicar
aws iam list-roles --query "Roles[?RoleName == 'example-role'].[RoleName, Arn]"
rem Asumir el role al usuario actual y ponerle un nombre de sesion
aws sts assume-role --role-arn "arn:aws:iam::768312754627:role/example-role" --role-session-name AWSCLI-Session >LlavesSesion.txt
rem Setear las variables de Entorno con la informacion de LlavesSesion.txt
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_SESSION_TOKEN=
set AWS_DEFAULT_REGION=us-east-1



rem Verificar que esta ejecutando el usuario adecuado
aws sts get-caller-identity
rem Volver a ejecutar el listado de acciones
aws ec2 describe-instances --query "Reservations[*].Instances[*].[VpcId, InstanceId, ImageId, InstanceType]"
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier, DBName, DBInstanceStatus, AvailabilityZone, DBInstanceClass]"


rem Si desea borrar los elementos que se crearon en este laboratorio se tiene que ejecutar en este orden. Volver a su usuario admin (mirar set AWS_SESSION_TOKEN=)
aws iam remove-user-from-group --group-name Dev --user-name Bob
rem obtener el access-keys para quitarla del usuario
aws iam list-access-keys --user-name Bob
aws iam delete-access-key --user-name Bob --access-key-id AKIA3FYYCIHBYIZPJ45M
aws iam delete-user --user-name Bob
aws iam detach-group-policy --group-name Dev --policy-arn "arn:aws:iam::768312754627:policy/example-policy"
aws iam delete-group --group-name Dev
aws iam delete-policy --policy-arn "arn:aws:iam::768312754627:policy/example-policy"
aws iam detach-role-policy --role-name example-role --policy-arn "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
aws iam delete-role --role-name example-role

rem Se puede modificar este laboratorio para que se use DynamoDB y S3 ya que son servicios Serverless para minimizar el costo y verificar acciones
rem En el example-Policy.json reemplazar la accion de "ec2:DescribeInstances" por "dynamodb:ListTables",
rem Luego, en el managedPolicy se reemplaza la politica "AmazonRDSReadOnlyAccess" por "AmazonS3ReadOnlyAccess"
rem y en las acciones de prueba use "aws dynamodb list-tables" y "aws s3api list-buckets --query "Buckets[].Name"