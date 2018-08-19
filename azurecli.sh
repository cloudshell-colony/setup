#!/bin/bash

echo -e "Preparing integration parameters"

#creting a random key
COLONY_RANDOM=$(date +%s | sha256sum | base64 | head -c 12;echo)$(echo $RANDOM)
COLONY_RANDOM="$(echo $COLONY_RANDOM | tr '[A-Z]' '[a-z]')"
COLONY_RANDOM="$(echo $(cat /proc/sys/kernel/random/uuid))"

AppName=$(echo "COLONY"$COLONY_RANDOM)
ColonyMgmtRG=$(echo "colony"$COLONY_RANDOM)
StorageName=$(echo "colony"$COLONY_RANDOM)
CosmosDbName=$(echo ""$ColonyMgmtRG"-sandbox-db")
AppKey=$(openssl rand -base64 32)
TenantId=$(az account show --query tenantId -o tsv)
SubscriptionId=$(az account show --query id -o tsv)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

REGION="westeurope"
if [ ! -z "$1" ]
then
      echo "Resources will be created udnder $1 region"
      REGION=$1      
fi

#cho -e "creating AD application for CloudShell Colony"
#z ad sp create-for-rbac -n $AppName --password $AppKey
#ppId=$(az ad app list --display-name $AppName | jq '.[0].appId' | tr -d \")
 
#cho -e "Configuring access to Azure API"
#ash -c "cat >> role.json" <<EOL
#{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
#OL
 
#az ad app update --id $AppId --required-resource-accesses role.json
#rm role.json
#echo -e "\n\nApplication Name = $AppName \nApplication ID = $AppId \nApplication Key = $AppKey \nTenant ID = $TenantId \nSubscription ID = $SubscriptionId"

#1.create resource group:
echo "${GREEN}---Creating colony resource group (1/3) "$ColonyMgmtRG
az group create -l $REGION -n $ColonyMgmtRG
echo "---Verifing Resource group exists "$ColonyMgmtRG 

if [ ! "$(az group exists -n $ColonyMgmtRG)" = "true" ]; then
        echo -e "Error resource group does not exists" 
        exit 1
fi

#2.Create the storage account:
echo "${GREEN}---Creating storage account (2/3) "$StorageName
az storage account create -n $StorageName -g $ColonyMgmtRG -l $REGION --sku Standard_LRS  --kind StorageV2 --tags colony-mgmt-storage=''
echo "---Verifing storage account exists "$StorageName 

#if storage account name is available it means that it was not created
if [ "$(az storage account check-name -n $StorageName -o json | jq -r .nameAvailable)" = "true" ]; then
        echo -e "Error storage account does not exists" 
        exit 1
fi


#3.Create mongo API cosmos db:
echo "${GREEN}---Creating CosmosDB (3/3) "$CosmosDbNames
az cosmosdb create -g $ColonyMgmtRG -n $CosmosDbName --kind MongoDB

echo "---Verifing CosmosDB exists "$CosmosDbName 
#if storage account name is available it means that it was not created
if [ ! "$(az cosmosdb check-name-exists -n $CosmosDbName)" = "true" ]; then
        echo -e "Error storage CosmosDB does not exists" 
        exit 1
fi

echo -e "\n\n\n-------------------------------------------------------------------------"
echo -e "Copy the text below and paste it into Colony's Azure authentication page \n\n$AppId,$AppKey,$TenantId,$SubscriptionId,$COLONY_RANDOM"
echo -e "-------------------------------------------------------------------------\n\n"

echo "Done"