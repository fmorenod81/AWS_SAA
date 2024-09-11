
rem **********************************************************************
rem LAB 3A: Sitio Web Estatico
rem **********************************************************************


rem Primero ingresar los datos de configuracion de la cuenta, obtenidos del archivo csv del IAM
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1

rem Hacer o descargar una pagina web para cargar la informacion. e.g Angular, React, NodeJS
rem se usa desde una carpeta llamada src
rem Adaptado de https://blog.eq8.eu/til/create-aws-s3-bucket-as-static-website-with-cli.html
rem Actualizado el 22/07/2024 con los cambios de AWS y la ayuda de tutorial en https://stackoverflow.com/questions/53385012/cannot-set-bucket-policy-of-amazon-s3
rem Un comparativo entre el uso de aws s3 y s3api se encuentra en https://aws.amazon.com/blogs/developer/leveraging-the-s3-and-s3api-commands/#:~:text=The%20main%20difference%20between%20the,provided%20by%20the%20s3api%20commands.

rem Se realiza la creacion del bucket. Revisar cuando tienen location diferente a us-east-1 https://github.com/aws/aws-cli/issues/2603
set  BucketName=www.ocidemo.online
aws s3api create-bucket --bucket %BucketName% --region us-east-1
rem Se especifican que pueda ser publico (Step 3 of https://docs.aws.amazon.com/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html#step3-edit-block-public-access)
aws s3api delete-public-access-block --bucket %BucketName%
rem Se habilita el Resource-Based Policy (Step 4 of https://docs.aws.amazon.com/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html#step3-edit-block-public-access)
aws s3api put-bucket-policy --bucket %BucketName% --policy file://bucket_policy.json
rem Se cargan los archivos
aws s3 sync ./src s3://%BucketName%/
rem Se habilita la caracteristica con las opciones minimas (Step 2 of https://docs.aws.amazon.com/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html#step3-edit-block-public-access)
aws s3 website s3://%BucketName%/ --index-document index.html --error-document error.html
rem Ir a www.ocidemo.online.s3-website.us-east-1.amazonaws.com

rem Otras opciones se pueden validar como colocar un ACL ante los objetos subidos
rem aws s3 sync ./src s3://%BucketName%/ --acl public-read