#!/bin/bash

# GLOBAL SOLUTION 2025 | DEVOPS & CLOUD COMPUTING | 2TDSPH
# MENTALANCE API
# André Luís Mesquita de Abreu  | RM: 558159
# Maria Eduarda Brigidio        | RM: 558575
# Rafael Bompadre Lima          | RM: 556459

# Registrar os serviços necessários
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationalInsights
az extension add --name application-insights
az provider register --namespace Microsoft.ServiceLinker

# Variáveis do projeto Mentalance
export RESOURCE_GROUP_NAME="rg-mentalance"
export WEBAPP_NAME="mentalance-api-app"
export APP_SERVICE_PLAN="mentalance-api"
export LOCATION="brazilsouth"
export RUNTIME="DOTNETCORE:8.0"
export APP_INSIGHTS_NAME="ai-mentalance"
export SQLSERVER="mentalancesqlserver"
export DBNAME="MentalanceDB"
export DBUSER="dbadmin"
export DBPASS="SenhaForte123!"

# Criar Grupo de Recursos
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location "$LOCATION"

# Criar Application Insights
az monitor app-insights component create \
  --app "$APP_INSIGHTS_NAME" \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --application-type web

# Criar o SQL Server
az sql server create \
    --name "$SQLSERVER" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --admin-user "$DBUSER" \
    --admin-password "$DBPASS"

# Criar o Banco de Dados
az sql db create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQLSERVER" \
    --name "$DBNAME" \
    --service-objective S0

# Criar Firewall do Banco - Permitir todos os IPs do Azure
az sql server firewall-rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQLSERVER" \
    --name AllowAllAzureIps \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0

# Criar o Plano de Serviço
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku F1 \
  --is-linux

# Criar o Serviço de Aplicativo
az webapp create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --plan "$APP_SERVICE_PLAN" \
  --runtime "$RUNTIME"

# Habilita a autenticação Básica (SCM)
az resource update \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --namespace Microsoft.Web \
  --resource-type basicPublishingCredentialsPolicies \
  --name scm \
  --parent sites/"$WEBAPP_NAME" \
  --set properties.allow=true

# Recuperar a String de Conexão do Application Insights
CONNECTION_STRING=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --query connectionString \
  --output tsv)

# Configurar as Variáveis de Ambiente necessárias do nosso App e do Application Insights
az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$CONNECTION_STRING" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
    XDT_MicrosoftApplicationInsights_Mode="Recommended" \
    XDT_MicrosoftApplicationInsights_PreemptSdk="1" \
    ConnectionStrings__DefaultConnection="Server=tcp:$SQLSERVER.database.windows.net,1433;Initial Catalog=$DBNAME;Persist Security Info=False;User ID=$DBUSER;Password=$DBPASS;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" \
    ASPNETCORE_ENVIRONMENT="Production" \
    DB_HOST="$SQLSERVER.database.windows.net" \
    DB_PORT="1433" \
    DB_NAME="$DBNAME" \
    DB_USER="$DBUSER" \
    DB_PASSWORD="$DBPASS"

# Reiniciar o Web App
az webapp restart \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME"

# Criar a conexão do nosso Web App com o Application Insights
az monitor app-insights component connect-webapp \
  --app "$APP_INSIGHTS_NAME" \
  --web-app "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME"

echo "=========================================="
echo "Deploy concluído com sucesso!"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Web App: $WEBAPP_NAME"
echo "SQL Server: $SQLSERVER.database.windows.net"
echo "Database: $DBNAME"
echo "Application Insights: $APP_INSIGHTS_NAME"
echo ""
echo "Para fazer o deploy do código, use:"
echo "az webapp deployment source config-zip --resource-group $RESOURCE_GROUP_NAME --name $WEBAPP_NAME --src <caminho-do-zip>"
echo ""
echo "Ou configure o deploy via:"
echo "az webapp deployment source config-local-git --resource-group $RESOURCE_GROUP_NAME --name $WEBAPP_NAME"

