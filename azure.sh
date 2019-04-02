#!/bin/bash
export AZURE_HTTP_USER_AGENT='pid-0b87316f-9d3a-427e-88cf-399fc4100b33'

function quit_on_err {
    echo $1                       
    exit 
}
           
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
REGION="westeurope"

if [ ! -z "$1" ]
then
      REGION=$1
fi

echo -e "\n\n   ___ _    ___  _   _ ___  ___ _  _ ___ _    _        ___ ___  _    ___  _  ___   __"
echo -e "  / __| |  / _ \| | | |   \/ __| || | __| |  | |  ___ / __/ _ \| |  / _ \| \| \ \ / /"
echo -e " | (__| |_| (_) | |_| | |) \__ \ __ | _|| |__| |_|___| (_| (_) | |_| (_) | .   \ V / "
echo -e "  \___|____\___/ \___/|___/|___/_||_|___|____|____|   \___\___/|____\___/|_|\_| |_|  \n\n\n"


echo -e "$GREEN Please wait while we setup the integration with your Azure account. $NC \n\n"
echo -e "This script grants Cloud Shell Colony permissions to your account and\ncreates a small management layer that will keep your data safe."
echo -e "For more information visit: https://colonysupport.quali.com/hc/en-us/articles/360008858093-Granting-access-to-your-Azure-account\n\n"
#========================================================================================
x=$(az account list)
accountname=$(az account show |jq -r .user.name)
length=$(jq -n "$x" | jq '. | length')
END=$length-1
i=0
declare -i subscription_number=0

if [ "$length" -eq 0 ]
then
        echo -e "${RED}Error no subscription found${NC}"
        exit 1
fi

if [ "$length" -eq 1 ]
then
        subscription_number=1
else 
        echo "Please type subscription number:#"
        while [[ $i -le $END ]]
        do
                # prints subscription name and id
                echo "$((i+1))" $(jq -n "$x" | jq .["$i"].name )  $(jq -n "$x" | jq .["$i"].id )
                ((i++))
        done

        read -p  "Please enter number between 1 to $length: " subscription_number

        while [  $subscription_number -lt 1 -o $subscription_number -gt $length ]
        do  
                read -p "Please enter number between 1 to $length: " subscription_number
        done
fi

SubscriptionId=$(jq -n "$x" | jq .["$((subscription_number-1))"].id -r)

echo -e "Running with settings:"
echo -e "Subscription:" $GREEN$(jq -n "$x" | jq .["$((subscription_number-1))"].name )  $SubscriptionId$NC
echo -e "Region $GREEN$REGION$NC"

#========================================================================================



#creting a random key
COLONY_RANDOM=$(date +%s | sha256sum | base64 | head -c 12;echo)$(echo $RANDOM)
COLONY_RANDOM="$(echo $COLONY_RANDOM | tr '[A-Z]' '[a-z]')"
AppName=$(echo "COLONY-"$COLONY_RANDOM)
ColonyMgmtRG=$(echo "colony-"$COLONY_RANDOM)
StorageName=$(echo "colony"$COLONY_RANDOM)
AppKey=$(openssl rand -base64 32)
TenantId=$(az account show --query tenantId -o tsv)


echo -e "Creating AD application for CloudShell Colony"
az ad sp create-for-rbac -n $AppName --password $AppKey --subscription $SubscriptionId ||  quit_on_err "The user that runs the script should be an Owner."
az ad sp credential reset -n $AppName --password $AppKey --end-date '2299-12-31' --subscription $SubscriptionId 
AppId=$(az ad app list --subscription $SubscriptionId --display-name $AppName | jq '.[0].appId' | tr -d \")

echo -e "Configuring access to Azure API"
bash -c "cat >> role.json" <<EOL
[{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
EOL
 
az ad app update --id $AppId --required-resource-accesses role.json --subscription $SubscriptionId
rm role.json
echo -e "\n\nApplication Name : $AppName \nApplication ID : $AppId \nApplication Key : $AppKey \nTenant ID : $TenantId \nSubscription ID : $SubscriptionId"

#========================================================================================


#1.create resource group:
echo -e "$GREEN---Creating resource group (1/2) "$ColonyMgmtRG$NC
az group create -l $REGION -n $ColonyMgmtRG --subscription $SubscriptionId --tags colony-mgmt-group='' owner=$accountname
echo "---Verifing Resource group exists "$ColonyMgmtRG 

if [ ! "$(az group exists -n $ColonyMgmtRG --subscription $SubscriptionId)" = "true" ]; then
        echo "Error resource group does not exists" 
        exit 1
fi

#2.Create the storage account:
echo -e "$GREEN---Creating storage account (2/2) "$StorageName$NC
az storage account create -n $StorageName -g $ColonyMgmtRG -l $REGION --sku Standard_LRS  --kind StorageV2 --tags colony-mgmt-storage='' --subscription $SubscriptionId
echo "---Verifing storage account exists "$StorageName 

#if storage account name is available it means that it was not created
if [ "$(az storage account check-name -n $StorageName -o json | jq -r .nameAvailable)" = "true" ]; then
        echo "Error storage account does not exists" 
        exit 1
fi

echo -e "$GREEN---Creating table in storage account"$NC
az storage table create -n colonySandboxes  --account-name $StorageName

echo -e "\n\n\n-------------------------------------------------------------------------"
echo "Copy the text below and paste it into Colony's Azure authentication page"
echo -e "${GREEN}appId:$AppId,appKey:$AppKey,tenantId:$TenantId,subscriptionId:$SubscriptionId,colonyResourceGroup:$ColonyMgmtRG${NC}"
echo -e "-------------------------------------------------------------------------\n\n"



                                                                                     
echo "Done"
