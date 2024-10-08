#!/bin bash

# Variables
RESOURCE_GROUP="LandingZone-RG"
LOCATION="uksouth"
VNET_NAME="LandingZone-VNet"
SUBNET_NAME="LandingZone-Subnet"
ADDRESS_SPACE="10.0.0.0/16"
SUBNET_RANGE="10.0.0.0/24"
VM_NAME="LandingZone-VM"
ADMIN_USERNAME="azureuser"
ADMIN_PASSWORD="P@ssw0rd123!" # Don't use this in production
IMAGE="Ubuntu2204"
SIZE="Standard_B1s"
POLICY_NAME="DenyPublicIP"

# Create Resource Group 
echo "Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Virtual Network and Subnet 
echo "Creating Virtual Network..."
az network vnet create --name $VNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --address-prefix $ADDRESS_SPACE \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix $SUBNET_RANGE

# Create a Virtual Machine (on free tier)
echo "Creating Virtual Machine..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image $IMAGE \
    --admin-username $ADMIN_USERNAME \
    --admin-password $ADMIN_PASSWORD \
    --size $SIZE \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --public-ip-sku Basic

# Apply a Tag for Governance
az tag create --resource-id $(az vm show --name $VM_NAME --resource-group $RESOURCE_GROUP --query "id" -o tsv) --tags Environment=Dev

# Enable Monitoring with Azure Monitor
echo "Enabling Monitor for the VM..."
az monitor diagnostic-settings create --resource $(az vm show $VM_NAME --resource-group $RESOURCE_GROUP --query "id" -o tsv) \
    --name "VMMonitor" \
    --metrics '[{"category": "AllMetrics", "enabled": true}]' \
    --logs '[{"category": "Administrative", "enabled": true}]'

# Apply Basic Governance with Azure Policy
echo "Creating and Assigning Azure Policy..."
az policy definition create --name $POLICY_NAME --rules '{"if":{"field":"type","equals":"Microsoft.Network/publicIPAddresses"},"then":{"effect":"deny"}}'
az policy assignment create --policy $POLICY_NAME --scope "/subscriptions/$(az account show --query id --output tsv)"

echo "Azure Landing Zone setup complete"