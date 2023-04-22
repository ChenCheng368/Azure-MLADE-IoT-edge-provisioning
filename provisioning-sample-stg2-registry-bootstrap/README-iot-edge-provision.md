# IoT Edge Installation and Provisioning Steps

## Problem Statement

During the past CSE customer engagements, we witness the needs to automate the process of IoT Edge installation on edge devices and provisioning to IoT Hub in a reasonable time interval (<2 minute per device).

The customers want to reduce cost and manual efforts by automating provisioning process.

This script is for the operator to install IoT Edge on edge device, and provision the edge device to IoT Hub with the preparation files prepared from the previous stage. Or the operator could provision the physical edge device without previous stage of creating simulated edge VM.

## Description

This repository is using Azure Resource Manager template and [iotedge-config tool](https://github.com/Azure-Samples/iotedge_config_cli) to create and provision the edge device as IoT Edge device to IoT Hub, and deploy the IoT Edge modules to the edge.

It includes the following actions:

1. Initialization and Azure account login.
2. Download x.509 certificates from Azure Key Vault.
3. Load private IP and FQDN of the edge device.
4. Config edge device with Edge Config Tool, including provisioning config, root certs, deployment manifest, etc.
5. Install IoT Edge on edge device.
6. Config X.509 root certs on IoT Edge device
7. Provisioning X.509 secured IoT Edge device to IoThub
8. deploy IoT Edge modules to the edge.

The installed IoT Edge will use AMQP/MQTT/AMQP-WS for communications. Please make sure those ports are open on the edge device.

The repository is working on Linux host environment and tested with Azure CLI ver 2.36.0.

Tier 1 operating systems supported by IoT Edge can be found [here](https://docs.microsoft.com/en-us/azure/iot-edge/support?view=iotedge-2020-11#tier-1).

## Getting Started

### Prerequisites

See the last section Preparation Guide for more details to create below resources.

- Azure subscription.
- IoT Hub instance in the above Azure subscription.
- Linux host environment that has internet access. As the scripts will download configuration packages from internet during run time.
- SSH key pairs used for accessing Azure IoT Edge VM. You may [create SSH key pair](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).  
- X.509 root CA certs should be pre-uploaded to Azure Key Vault. You may use your own X.509 certs or [create a demo certs](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-create-test-certificates?view=iotedge-2020-11&tabs=linux) for testing purpose.

### Environment Variables

- IOT_HUB_NAME - Name of your IoT Hub in your subscription. Don't use the FQDN name of the IoT Hub.
- SUBSCRIPTION - Subscription where your IoT Hub is located.
- RESOURCE_GROUP_NAME - Give a Resource Group name at your preference
- RESOURCE_GROUP_LOCATION - The Azure Data Center region where you want the Edge network and VM's to be created.
- VM_NAME - Give a VM name at your preference
- ADMIN_USER_NAME - The name you want to use as the admin account on the Edge VM's.
- UNIQUE_DNS_PREFIX - String of your choosing which will be used a prefix for the VM names on their public IP addresses.
- X509_CERT - The name only (not the full path) of your X.509 root CA cert.
- X509_KEY - The name only (not the full path) of your X.509 root CA key.
- KEY_VAULT_NAME - Azure Key Vault name that stores the x509 certs.
- CERTIFICATE_NAME - Certificate name that's in the Azure Key Vault.
- DOWNLOAD_FILE_NAME - A local file name you give to save the downloaded certs into.
- SVS_PRI_ID - (optional) For service principle Azure login only. service principle app ID.
- SVS_PRI_PW - (optional) For service principle Azure login only. service principle password
- TENANT - (optional) For service principle Azure login only. Directory (tenant) ID of the service principle

### Optional Parameters

- -d    : Deployment manifest file to be used for the initial deployment. Default is the deployment manifest with only IoT Edge Runtime modules.
- -o    : Custom openssl path. Default is openssl in system PATH environment.
- -l    : Enable automatic Azure login mode with Service Principles. Default is manual Azure login with Azure account.
- -s    : Enable silent mode to redirect stdout from console. Default is false.
- -h    : Help

### Steps

1. Clone the repo to your local Linux environment.
2. Copy env-template.sh in repo to .env-edge.sh (or any file starting with “.env” which will be ignored by the .gitignore file)
3. Set the required variables in the .env-edge.sh file, following the comments in the file. See details in section Input Variables.
4. Load environment variables into your local Linux shell

    ```bash
    source .env-edge.sh
    ```

5. Set file system access permission on deploy-edge-VM-x509.sh.

    ```bash
    chmod +x deploy-edge-VM-x509.sh
    ```

6. Run deploy-edge-VM-x509.sh in your Linux environment to deploy IoT Edge Runtime modules only.

    ```bash
    ./deploy-edge-VM-x509.sh
    ```

    or add optional parameter -d to choose the targeted deployment manifest.

    ```bash
    ./deploy-edge-VM-x509.sh -d <deployment-manifest>
    ```

7. Go to your IoT Hub portal and check the deployed IoT Edge VM. If things work as intended, you should have IoT Edge VM in your IoT Hub running and reporting connected status.  

## Preparation Guide

### Create an Azure subscription

Try a free Azure subscription [here](https://azure.microsoft.com/en-us/free/).

### Create Azure IoT Hub

>Note:  If you already have an IoT Hub account, skip this step.

Follow instructions in this [tutorial](https://docs.microsoft.com/en-us/azure/iot-edge/quickstart-linux?view=iotedge-2020-11) to create your IoT Hub.

Understand more on IoT Hub [here](https://azure.microsoft.com/en-us/services/iot-hub/#overview).

### Install Openssl

If the host machine has csr permission issue, you will need to install and config your openssl to your host Path via follow steps 1~5 in <https://linuxpip.org/install-openssl-linux/>

### Clean Up Resources

Delete the Resource Group together with all the resources it contains:

```bash
az group delete --name <resource-group-name>
```
