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
   -z ${DNS_FOR_PUBLIC_IP} ||
   -z ${X509_CERT+x} ||
   -z ${X509_KEY+x}
   ]];
then 
  echo "Required environment variables not set. See README.MD for instructions."
  exit 1
fi

usage(){
    echo "***Script to provision edge device to IoT Hub and deploy IoT Edge modules ***"
    echo "This script is for Robot Deployer to provision edge device as IoT Edge Device to IoT Hub "
    echo "and make an initial deployment of custom modules. We take ROS modules as example."
    echo "*****************************************************************************"
    echo "---Optional Parameters--- "
    echo "-d    : deployment manifest file to be used for the initial deployment. Default is the deployment manifest with only IoT Edge Runtime modules."
    echo "-o    : custom openssl path. Default is openssl in system PATH environment."
    echo "-l    : enable automatic Azure login mode with Service Principles. Default is manual Azure login with Azure account."
    echo "-s    : enable silent mode to redirect stdout from console. Default is false."
}

# get the options
while getopts ":l:s:d:o:h" OPTION; do
	case $OPTION in
    l)
      l="true" 
      ;;
    s)
      s="true"
      ;;
    d)
      d=$OPTARG
      ;;
    o)
      o=$OPTARG
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
deploy_manifest_file=${d:-""}
openssl_path=${o:-""}

deploy_manifest_file_default="deployment-default.json"
iot_hub_host_name=$IOT_HUB_NAME".azure-devices.net"

##************************************************************************************************##
##********************************************** Initialize **************************************##
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

##************************************************************************************************##
##*********************** download x.509 certificates from Key Vault *****************************##
##************************************************************************************************##

# verify required variables for downloading x.509 are set
if [[
   -z ${KEY_VAULT_NAME} ||
   -z ${CERTIFICATE_NAME} ||
   -z ${DOWNLOAD_FILE_NAME}
   ]];
then 
  echo "Required environment variables for downloading x.509 certs are not set. See README.MD for instructions."
  exit 1
fi

if [ -e ${DOWNLOAD_FILE_NAME} ]
then
    rm ${DOWNLOAD_FILE_NAME}
fi

az keyvault secret download --name ${CERTIFICATE_NAME} --vault-name ${KEY_VAULT_NAME} --file ${DOWNLOAD_FILE_NAME}

if [ ! -e ${DOWNLOAD_FILE_NAME} ]
then
    echo "Failed to download certificate from Key Vault."
    exit 1
fi

# split into certificate and private key
csplit -z -f cert -n 1 ${DOWNLOAD_FILE_NAME} "/^-----BEGIN CERTIFICATE-----$/"
mv cert0 "./preparation-files/x509-certs/private/${X509_KEY}"
mv cert1 "./preparation-files/x509-certs/certs/${X509_CERT}"

# check the fingerprints
echo "The fingerprint of the certificate is:"
openssl x509 -fingerprint -noout -in "./preparation-files/x509-certs/certs/${X509_CERT}"

echo "The fingerprint of the private key is:"
openssl pkcs8 -in "./preparation-files/x509-certs/private/${X509_KEY}" -nocrypt -topk8 -outform DER | openssl sha1 -c


##************************************************************************************************##
##***************************************** Provision Edge VM  ***********************************##
##************************************************************************************************##

# load private IP and FQDN variables string
edge_private_IP_str=$(jq .edge_private_IP ./preparation-files/edgeVMfile.json)
edge_FQDN_str=$(jq .edge_FQDN ./preparation-files/edgeVMfile.json)
# convert string output to array
eval "edge_private_IP=($edge_private_IP_str)"
eval "edge_FQDN=($edge_FQDN_str)"

#start time
time1=$(date +%s)
echo "start ts: $time1"

# download and unpack edge config tool
rm -rf ./output
mkdir ./output
cd ./output
wget "https://github.com/Azure-Samples/iotedge_config_cli/releases/download/latest/iotedge_config_cli.tar.gz"
tar -xvf iotedge_config_cli.tar.gz

# copy template files for tutorial
cd iotedge_config_cli_release
cp ./templates/tutorial/*.json .
cp ./templates/tutorial/*.toml .
cp ../../preparation-files/x509-certs/certs/${X509_CERT} .
cp ../../preparation-files/x509-certs/private/${X509_KEY} .
 
# use VM name as the device ID's in IoT Hub
EDGE_DEVICE_ID=${VM_NAME}

# write out nested edge config tool YAML file, inserting values for IoT Hub, device ID, and private IP addresses 
file="./iotedge_config.yaml"

cat << EOT > $file
config_version: "1.0"
iothub:
  iothub_hostname: "${iot_hub_host_name}"
  iothub_name: "${IOT_HUB_NAME}"
  ## Authentication method used by IoT Edge devices: symmetric_key or x509_certificate
  authentication_method: x509_certificate 

## Root certificate used to generate device CA certificates. Optional. If not provided a self-signed CA will be generated
certificates:
  root_ca_cert_path: "./${X509_CERT}"
  root_ca_cert_key_path: "./${X509_KEY}"

## IoT Edge configuration template to use
configuration:
  template_config_path: "./device_config.toml"
  default_edge_agent: "\$upstream:8000/azureiotedge-agent:1.2"

## Config IoT Edge devices
edgedevices:
  device_id: ${EDGE_DEVICE_ID}
  edge_agent: "mcr.microsoft.com/azureiotedge-agent:1.2" ## Optional. If not provided, default_edge_agent will be used
  deployment: "./deploymentTopLayer.json" ## Optional. If provided, the given deployment file will be applied to the newly created device
  hostname: "${edge_private_IP}"

EOT

deploy_manifest_file_len=${#deploy_manifest_file}
if [ $deploy_manifest_file_len -eq 0 ]
then
    echo "using default deployment manifest: "
    echo "deployment-default.json"
    cp ../../preparation-files/$deploy_manifest_file_default .
    rm -rf ./deploymentTopLayer.json
    mv ./$deploy_manifest_file_default ./deploymentTopLayer.json

else 
    echo "using deployment manifest: " 
    echo $deploy_manifest_file
    cp ../../preparation-files/$deploy_manifest_file .
    rm -rf ./deploymentTopLayer.json
    mv ./$deploy_manifest_file ./deploymentTopLayer.json
fi

# iotedge config tool issues azure cli commands which assume current account has access to IoT Hub
az account set --subscription ${SUBSCRIPTION}

openssl_path_len=${#openssl_path}
if [ $openssl_path_len -eq 0 ]
then
    echo "using default openssl as in system PATH"
    ./iotedge_config --config ./iotedge_config.yaml --output ./ -f 
else 
    echo "using custom openssl path "
    ./iotedge_config --config ./iotedge_config.yaml --output ./ -f --openssl-path $openssl_path
fi


# copy iot edge config tool generated packages to VM's   
scp -o StrictHostKeyChecking=accept-new ./${EDGE_DEVICE_ID}.zip ${ADMIN_USER_NAME}@${edge_FQDN}:~

# run script to install docker, Azure IoT Edge, generated package configurations
cd ../..
az vm run-command invoke --command-id RunShellScript --parameters  "ADMIN_USER_NAME=${ADMIN_USER_NAME}" "DEVICE_ID=${EDGE_DEVICE_ID}" --scripts @install-edge.sh --name "${VM_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" --subscription "${SUBSCRIPTION}"

#time consumed
time6=$(date +%s)
echo "provisioning time duration: $(($time6-$time1)) seconds"
