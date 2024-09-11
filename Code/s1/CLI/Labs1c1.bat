rem Se puede generar haciendo aws configure or configurandoloes en el archivo <Home Directory>\.aws\credentiales

rem Primero ingresar los datos de configuracion de la cuenta, obtenidos del archivo csv del IAM
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
set AWS_DEFAULT_REGION=us-east-1
rem Obtenemos datos de la cuenta por medio de una obtencion de identidad STS
aws sts get-caller-identity
aws sts get-caller-identity --query Account 
aws sts get-caller-identity --query Account --output text
rem Unicamente obtenemos un valor de esa cuenta, podriamos realizarlo usando jq si tenemos json
aws sts get-caller-identity|jq ".Account"
rem Obtener variable ejecutada en entorno
aws sts get-caller-identity --query Account --output text >tmpFile
set /p accountId= < tmpFile 
del tmpFile 
echo La variable de entorno es %accountId%
rem Vamos a traer el listado de regiones que estan disponibles para esa cuenta
aws ec2 describe-regions
rem Vamos a traer alguna informacion del budget que realizamos recientemente
aws budgets describe-budgets --account-id %accountId% 
aws budgets describe-budgets --account-id %accountId% |jq ".Budgets[0].BudgetName"