rem Clave del usuario
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1


rem Recuerde ir a la carpeta de este laboratorio donde se encuentan los archivos json y javascript; y alli ejecutan desde consola estos comandos.

rem SECCION CREAR TABLA PARA DYNAMODB STREAM
rem Crear la base de datos original, asignarle RCU y WCU bajos para este caso son 5 pero si quieres hacer mas pruebas puedes llegar hasta 25 en la capa gratuita.
rem Crearle Partition and Sort Key, recordar que se llaman HASH y RANGE key dentro AWS tambien. Recordar que la llave compuesta no permite escribir ambos valores iguales para un registro
rem Activarle el Stream a la tabla para realizarle las acciones de eventos al Lambda.
aws dynamodb create-table --table-name BarkTable --attribute-definitions AttributeName=Username,AttributeType=S AttributeName=Timestamp,AttributeType=S --key-schema AttributeName=Username,KeyType=HASH  AttributeName=Timestamp,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES
rem Obtener la region y el AccountID. Aqui se almacenan la region y el AccountID en mi caso es el us-east-1 y 768312754627

rem SECCION CREAR SNS TOPIC EN SNS Y SUBSCRIBIRSE
rem Crear SNS Topic. Es necesario crear un topic para al enviar un evento se publicado en los correos suscritos.
aws sns create-topic --name wooferTopic
rem Subscribir el correo electronico al SNS Topic. Modificar region, accountID y el correo electronico a su correo personal.
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:768312754627:wooferTopic --protocol email --notification-endpoint fmorenod@gmail.com
rem Ir a su correo electronico y aceptarlo la suscripcion.
rem TAREA: Copiar el correo electronico de la suscripcion.

rem SECCION CREAR ROLE, LA FUNCION LAMBDA Y PROBARLA
rem Crear el Role para ejecucion del Lambda y su alcance basado en Trusted Entity. El archivo json debe ser visualizado desde la consola.
aws iam create-role --role-name WooferLambdaRole --path "/service-role/" --assume-role-policy-document file://trust-relationship.json
rem Asignarle permisos al role. Modificar el archivo json role-policy.json para ponerle region y account ID: en mi caso era us-east-1 y 768312754627
rem En este caso asignarles los permisos especificos al role de los recursos a usar: DynamoDB Streams, SNS - Notificaciones, y ejecucion del lambda.
aws iam put-role-policy --role-name WooferLambdaRole --policy-name WooferLambdaRolePolicy --policy-document file://role-policy.json
rem Modificar el archivo publishNewBark.js con la region y accountID correcto y luego crear el archivo comprimido, aqui uso "zip" que viene incluido en mi windows.
rem zip publishNewBark.zip publishNewBark.js
"C:\Program Files\7-Zip\7z.exe" a publishNewBark.zip publishNewBark.js
rem Confirmar que el role fue creato y obtener el role ARN para crear la funcion con el role adecuado.
aws iam get-role --role-name WooferLambdaRole
rem Crear la funcion lambda: con codigo, Role ARN (obtenido del paso anterior) y enviar el codigo comprimido, version de lenguaje nodejs.10 y funcion a ejecutar
aws lambda create-function --region us-east-1 --function-name publishNewBark --zip-file fileb://publishNewBark.zip --role arn:aws:iam::768312754627:role/service-role/WooferLambdaRole --handler publishNewBark.handler --timeout 5 --runtime nodejs16.x
rem Probar la funcion creada enviando un json (payload.json) abriendo el achivo de salida (output.txt)
aws lambda invoke  --function-name publishNewBark --cli-binary-format raw-in-base64-out --payload file://payload.json output.txt
rem Comprobar la respuesta 200 en el StatusCode y que el mensaje del archivo output.json asi como el correo electronico con la notificacion
rem TAREA: Copiar el correo electronico de la prueba.

rem SECCION VINCULAR FUENTE DEL LAMBDA COMO DYNAMODB STREAMS Y ALAMCENAR UN REGISTRO AL DYNAMOD
rem Obtener el Latest Stream ARN (Ultimo eventos Stream generado del campo LatestStreamArn)
aws dynamodb describe-table --table-name BarkTable
rem Crear el origen de llamada al Lambda, al reemplazar event-source con el LatestStreamArn obtenido del paso anterior.
aws lambda create-event-source-mapping --region us-east-1 --function-name publishNewBark --batch-size 1 --starting-position TRIM_HORIZON --event-source arn:aws:dynamodb:us-east-1:768312754627:table/BarkTable/stream/2024-07-31T11:34:33.476
rem Crear un registro en DynamoDB
aws dynamodb put-item --table-name BarkTable --item Username={S="Francisco Moreno "},Timestamp={S="2024-07-11 16:14:32:17"},Message={S="Mensaje de Prueba 1...2..3.434324234....3.."}
aws dynamodb put-item --table-name BarkTable --item Username={S="Nombre del Barrio Donde Vive"},Timestamp={S="2024-07-16:14:32:17"},Message={S="Mensaje de Prueba 1...2..3"}


rem Clean
rem DynamoDB table
aws dynamodb  delete-table --table-name BarkTable
rem SNS Topic
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:768312754627:wooferTopic
rem Lambda
aws lambda  delete-function --function-name publishNewBark
rem Role
aws iam delete-role-policy --role-name WooferLambdaRole --policy-name WooferLambdaRolePolicy
aws iam delete-role --role-name WooferLambdaRole
rem Cloudwatch Logs
aws logs delete-log-group --log-group-name /aws/lambda/publishNewBark