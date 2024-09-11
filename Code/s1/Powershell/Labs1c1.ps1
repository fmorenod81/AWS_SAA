<# Se puede generar haciendo aws configure or configurandoloes en el archivo <Home Directory>\.aws\credentiales #>

<# Primero ingresar los datos de configuracion de la cuenta, obtenidos del archivo csv del IAM #>
$Env:AWS_ACCESS_KEY_ID=""
$Env:AWS_SECRET_ACCESS_KEY=""
$Env:AWS_DEFAULT_REGION="us-east-1"

<# Obtenemos datos de la cuenta por medio de una obtencion de identidad STS #>
Get-STSCallerIdentity
<# Unicamente obtenemos un valor de esa cuenta, podriamos realizarlo usando jq si tenemos json #>
(Get-STSCallerIdentity).Account
$accountId = @(Get-STSCallerIdentity).Account
$accountId
<# Vamos a traer el listado de regiones que estan disponibles para esa cuenta #>
Get-EC2Region
<# Vamos a traer alguna informacion del budget que realizamos recientemente #>
Get-BGTBudgetList -AccountId $accountId