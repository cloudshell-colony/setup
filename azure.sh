echo -e "preparing integration parameters"
AppName=$(echo "COLONY"$RANDOM)
AppKey=$(openssl rand -base64 32)
TenantId=$(az account show --query tenantId -o tsv)
SubscriptionId=$(az account show --query id -o tsv)
 
echo -e "creating AD application for CloudShell Colony"
az ad sp create-for-rbac -n $AppName --password $AppKey
AppId=$(az ad app list --display-name $AppName | jq '.[0].appId' | tr -d \")
 
echo -e "Configuring access to Azure API"
bash -c "cat >> role.json" <<EOL
[{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
EOL
 
az ad app update --id $AppId --required-resource-accesses role.json
rm role.json
echo -e "\n\nApplication Name = $AppName \nApplication ID = $AppId \nApplication Key = $AppKey \nTenant ID = $TenantId \nSubscription ID = $SubscriptionId"

echo -e "\n\n\n-------------------------------------------------------------------------"
echo -e "Copy the token below and paste it into Colony's Azure authentication page \n\nTOKEN\n$AppId,$AppKey,$TenantId,$SubscriptionId"
echo -e "-------------------------------------------------------------------------\n\n"

