#!/bin/bash
exec 6>&1 # saves stdout

set -e

# verify required variables are set
if [[
   -z ${IOT_HUB_NAME} ||
   -z ${SUBSCRIPTION+x} ||
   -z ${RESOURCE_GROUP_NAME} ||
   -z ${RESOURCE_GROUP_LOCATION+x} ||
   -z ${VM_NAME+x} ||
   -z ${ADMIN_USER_NAME+x} ||
   -z ${DNS_FOR_PUBLIC_IP}
   ]];
then 
  echo "Required environment variables not set. See README.MD for instructions."
  exit 1
fi

usage(){
    echo "***Script to Prepare Azure VM as Edge Device ***"
    echo "This script is to create an Azure VM to simulate the edge device "
    echo "for the Operator to proceed the provisioning process. "
    echo "************************************************"
    echo "---Optional Parameters--- "
    echo "-l    : enable automatic Azure login mode with Service Principles. Default is manual Azure login with Azure account."
    echo "-s    : enable silent mode to redirect stdout from console. Default is false."
}

# get the options
while getopts "lsh" OPTION; do
	case $OPTION in
    l)
      l="true" 
      ;;
    s)
      s="true"
      ;;
    h)
      usage
      exit 1
      ;;
    \?)
      echo "Error: Invalid option"
      exit 1
      ;;
	esac
done
shift $((OPTIND-1))

auto_az_login_mode=${l:-"false"} 
silent_mode=${s:-"false"}

##************************************************************************************************##
##********************************* Host Machine Environment Setup *******************************##
##************************************************************************************************##
# silent mode
if [ $silent_mode == "true" ]
then
    echo "silent mode"
    exec > /dev/null  # redirect stdout to /dev/null
else 
    exec 1>&6 6>&- # restore stdout
fi

# Install Azure CLI and aziot extension
sudo apt update && sudo apt install -y curl
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-iot

# Azure login
if [ $auto_az_login_mode == "true" ]
then
    # auto login Azure with service principle
    # verify required variables are set
    if [[
      -z ${SVS_PRI_ID} ||
      -z ${SVS_PRI_PW} ||
      -z ${TENANT}
      ]];
    then 
      echo "Required service principles variables not set. See README.MD for instructions."
      exit 1
    fi
    az cloud set -n AzureCloud
    az login --service-principal -u ${SVS_PRI_ID} --password=${SVS_PRI_PW} --tenant ${TENANT}
    echo "Azure account is logged in!"
else
    # manual login
    az login   
    az version
    echo "Azure account is logged in!"
fi

iot_hub_host_name=$IOT_HUB_NAME".azure-devices.net"

##************************************************************************************************##
##******************************************* Edge VM Creation ***********************************##
##************************************************************************************************##
# create resource group
az group create \
  --subscription "${SUBSCRIPTION}" \
  --name $RESOURCE_GROUP_NAME \
  --location "${RESOURCE_GROUP_LOCATION}"

# create vnet
az deployment group create \
  --subscription "${SUBSCRIPTION}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --template-file "edge-network.json"

# create edge VM and read private IP and FQDN output into string variable
output_str=$(az deployment group create \
  --subscription "${SUBSCRIPTION}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --template-file "ubuntu.json" \
  --parameters "edge-network.parameters.json" \
  --parameters \
      virtualNetworkResourceGroup="${RESOURCE_GROUP_NAME}" \
      vmName="${VM_NAME}" \
      adminUsername="${ADMIN_USER_NAME}" \
      sshKeyData="$(< ~/.ssh/id_rsa.pub)" \
      dnsNameForPublicIP="${DNS_FOR_PUBLIC_IP}" \
  --query "properties.outputs.[privateIp.value, fqdn.value]" \
  --output tsv | tee /dev/tty)

# convert string output to array
readarray -t edge_output <<<"${output_str}"

# initialize individual private IP and FQDN variables
edge_private_IP=${edge_output[0]}
edge_FQDN=${edge_output[1]}

# write IP and FQDN to files folder
file="./preparation-files/edgeVMfile.json"
cat << EOT > $file
{
    "edge_private_IP": "${edge_private_IP}",
    "edge_FQDN": "${edge_FQDN}",
    "resource_group_name": "${RESOURCE_GROUP_NAME}"
}  
EOT

