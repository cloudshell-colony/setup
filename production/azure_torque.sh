#!/bin/bash
export AZURE_HTTP_USER_AGENT='pid-0b87316f-9d3a-427e-88cf-399fc4100b33'

function quit_on_err { echo $1; exit; }
function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
function run_and_capture {
    typeset -n var_out=$1
    typeset -n var_err=$2
    typeset -n var_code=$3
    seperator=$(dbus-uuidgen)
    std=$(
        { stdout=$($4) ; } 2>&1
        echo -e "$seperator$stdout$seperator$?"
    )
    var_err="${std%%$seperator*}"; std="${std#*$seperator}"
    var_out="${std%%$seperator*}"; std="${std#*$seperator}"
    var_code="${std%%$seperator*}"; std="${std#*$seperator}"
}
function retry(){
    max_retries=$1
    command="$2"
    retries=0
    while [ $retries \< $max_retries ]; do
        run_and_capture stdout stderr exit_code "$command"
        echo "$stderr" >&2
        if [ $exit_code == "0" ]; then
            break
        elif [[ "$stderr" == *"too many 500 error responses"* ]]; then
            sleep 1
        else
            break
        fi
        retries=$((retries+1))
    done
    echo "$stdout"
    return $exit_code
}

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
REGION="westeurope"

if [ ! -z "$1" ]
then
      REGION=$1
fi

echo -e "\n\n"
echo -e "████████╗░█████╗░██████╗░░██████╗░██╗░░░██╗███████╗"
echo -e "╚══██╔══╝██╔══██╗██╔══██╗██╔═══██╗██║░░░██║██╔════╝"
echo -e "░░░██║░░░██║░░██║██████╔╝██║██╗██║██║░░░██║█████╗░░"
echo -e "░░░██║░░░██║░░██║██╔══██╗╚██████╔╝██║░░░██║██╔══╝░░"
echo -e "░░░██║░░░╚█████╔╝██║░░██║░╚═██╔═╝░╚██████╔╝███████╗"
echo -e "░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░░╚═════╝░╚══════╝ \n\n\n"


echo -e "$GREEN Please wait while we setup the integration with your Azure account. $NC \n\n"
echo -e "This script grants Torque permissions to your account and\ncreates a small management layer that will keep your data safe."
echo -e "For more information visit: https://community.qtorque.io/microsoft-azure-54/adding-an-azure-cloud-account-321\n\n"
#========================================================================================

AZ_VERSION=$(az --version | grep -Po 'azure\-cli.*\K(\d+\.\d+\.\d+)')
if [ $(ver $AZ_VERSION) -lt $(ver 2.0.69) ]; then
    echo -e "${RED}Unsupported azure-cli version of $AZ_VERSION. Please update to version 2.0.68 or above.${NC}"
    exit 1
fi

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

az account set --subscription $SubscriptionId

echo -e "Running with settings:"
echo -e "Subscription:" $GREEN$(jq -n "$x" | jq .["$((subscription_number-1))"].name )  $SubscriptionId$NC
echo -e "Region $GREEN$REGION$NC"

#========================================================================================

TORQUE_RANDOM=$(date +%s | sha256sum | base64 | head -c 12;echo)$(echo $RANDOM)
TORQUE_RANDOM="$(echo $TORQUE_RANDOM | tr '[A-Z]' '[a-z]')"
AppName=$(echo "TORQUE-"$TORQUE_RANDOM)
TorqueMgmtRG=$(echo "torque-"$TORQUE_RANDOM)
StorageName=$(echo "torque"$TORQUE_RANDOM)
TenantId=$(az account show --query tenantId -o tsv)
SidecarIdentityName=$(echo $TorqueMgmtRG"-sidecar-identity")


echo -e "Creating AD application for Torque"
AppKey=$(az ad sp create-for-rbac -n $AppName | jq -r '.password') ||  quit_on_err "The user that runs the script should be an Owner."
AppId=$(az ad app list --display-name $AppName | jq '.[0].appId' | tr -d \")
az ad sp credential reset -n $AppName --password $AppKey --end-date '2299-12-31'


echo -e "Configuring access to Azure API"
bash -c "cat >> role.json" <<EOL
[{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
EOL

az ad app update --id $AppId --required-resource-accesses role.json
rm role.json
echo -e "\n\nApplication Name : $AppName \nApplication ID : $AppId \nApplication Key : $AppKey \nTenant ID : $TenantId \nSubscription ID : $SubscriptionId"

#========================================================================================


#1.create resource group:
echo -e "$GREEN---Creating resource group (1/3) "$TorqueMgmtRG$NC
az group create -l $REGION -n $TorqueMgmtRG --tags torque-mgmt-group='' owner=$accountname
echo "---Verifing Resource group exists "$TorqueMgmtRG

if [ ! "$(az group exists -n $TorqueMgmtRG)" = "true" ]; then
        echo "Error resource group does not exists"
        exit 1
fi

#2.Create the storage account:
echo -e "$GREEN---Creating storage account (2/3) "$StorageName$NC
az storage account create -n $StorageName -g $TorqueMgmtRG -l $REGION --sku Standard_LRS  --kind StorageV2 --tags torque-mgmt-storage=''
echo "---Verifing storage account exists "$StorageName

#if storage account name is available it means that it was not created
if [ "$(az storage account check-name -n $StorageName -o json | jq -r .nameAvailable)" = "true" ]; then
        echo "Error storage account does not exists"
        exit 1
fi

echo -e "$GREEN---Creating table in storage account"$NC
az storage table create -n torqueSandboxes  --account-name $StorageName

#3. create sidecar identity
echo -e "$GREEN---Creating managed identity (3/3) "$SidecarIdentityName$NC
SidecarIdentityPrincipalId=$(retry 5 "az identity create -n $SidecarIdentityName -g $TorqueMgmtRG -l $REGION --query principalId --out tsv") \
  || quit_on_err "Error creating managed identity"

# assigning the identity with Contributor role in the subscription
echo -e "$GREEN---Assigning role to the managed identity"$NC
az role assignment create --assignee-object-id $SidecarIdentityPrincipalId --assignee-principal-type "ServicePrincipal" --role "Contributor" --scope "/subscriptions/"$SubscriptionId \
  || quit_on_err "Error assigning role to managed identity"

echo -e "\n\n\n-------------------------------------------------------------------------"
echo "Copy the text below and paste it into Torque's Azure authentication page"
echo -e "${GREEN}appId:$AppId,appKey:$AppKey,tenantId:$TenantId,subscriptionId:$SubscriptionId,torqueResourceGroup:$TorqueMgmtRG${NC}"
echo -e "-------------------------------------------------------------------------\n\n"




echo "Done"
