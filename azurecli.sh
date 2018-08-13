#!/bin/bash
echo -e "preparing integration parameters"
REGION="westeurope"
AppName=$(echo "COLONY"$RANDOM)
ColonyMgmtRG=$(echo "colony-mgmt-"$RANDOM)
StorageName=$(echo "storagecolonymgmt"$RANDOM)
CosmosDbName=$(echo ""$ColonyMgmtRG"-sandbox-db")

AppKey=$(openssl rand -base64 32)
TenantId=$(az account show --query tenantId -o tsv)
SubscriptionId=$(az account show --query id -o tsv)

 
#echo -e "creating AD application for CloudShell Colony"
#az ad sp create-for-rbac -n $AppName --password $AppKey
#AppId=$(az ad app list --display-name $AppName | jq '.[0].appId' | tr -d \")
 
#echo -e "Configuring access to Azure API"
#bash -c "cat >> role.json" <<EOL
#[{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
#EOL
 
#az ad app update --id $AppId --required-resource-accesses role.json
#rm role.json
#echo -e "\n\nApplication Name = $AppName \nApplication ID = $AppId \nApplication Key = $AppKey \nTenant ID = $TenantId \nSubscription ID = $SubscriptionId"

#1.create resource group:
echo "---Creating colony resource group (1/3) "$ColonyMgmtRG
az group create -l $REGION -n $ColonyMgmtRG

#2.Create mongo API cosmos db:
echo "---Creating cosmos DB (2/3)"$CosmosDbName
az cosmosdb create -g $ColonyMgmtRG -n $CosmosDbName --kind MongoDB

#3.Create the storage account:
echo "---Creating storage account (3/3)"$StorageName
az storage account create -n $StorageName -g $ColonyMgmtRG -l $REGION --sku Standard_LRS --tags colony-mgmt-storage:''

echo -e "\n\n\n-------------------------------------------------------------------------"
echo -e "Copy the token below and paste it into Colony's Azure authentication page \n\nTOKEN\n$AppId,$AppKey,$TenantId,$SubscriptionId,$ColonyMgmtRG"
echo -e "-------------------------------------------------------------------------\n\n"

echo "Done"
