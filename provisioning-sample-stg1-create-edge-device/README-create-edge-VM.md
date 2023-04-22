# Edge VM Preparation User Guides

## Problem Statement

During the past CSE customer engagements, we witness the needs to automate the process of IoT Edge installation on edge devices and provisioning to IoT Hub in a reasonable time interval (<2 minute per device).

The customers want to reduce cost and manual efforts by automating provisioning process.

This script is to create an Azure VM to simulate edge device for the operator to proceed the provisioning process at the next stage.  

## Description

This repository is creating an Azure VM with Ubuntu 18.04 image as a simulated edge device for the provisioning process at the next stage.

It includes the following actions:

1. Create Azure Resource Group.
2. Create Azure VM instance (Ubuntu LTS 18.04) as edge device, assigning VNET public IP for SSH access only. Password is disabled.
3. Abstract the Azure VM configuration information and save it to file.

Private IP and FQDN of the created VM will be saved in the output file edgeVMfile.json, which are the required inputs for the provisioning process at the next stage.

The repository works on Linux Ubuntu environment. Azure CLI ver 2.36.0 is used.

## Getting Started

### Prerequisites

See section Preparation Guide for more details to create below resources.

- Azure subscription.
- IoT Hub instance in the above Azure subscription.
- Linux host machine and the host environment has internet access.
- SSH key pairs used for accessing Azure IoT Edge VM. You may [create SSH key pair](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).  

### Steps

1. Clone the repo to your local Linux environment.
2. Place SSH key pair into your Linux environment folder /home/{user}/.ssh/
3. Copy env-template.sh in repo to ./preparation-files/.env-edge.sh (or any file starting with “.env” which will be ignored by the .gitignore file)
4. Set the required variables in the ./preparation-files/.env-edge.sh file, following the comments in the file. See details in section Input Variables.
5. Load environment variables into your local Linux shell

    ```bash
    source ./preparation-files/.env-edge.sh
    ```

6. Run prepare-edge-VM.sh from your Linux host environment:

    ```bash
    chmod +x prepare-edge-VM.sh
    ./prepare-edge-VM.sh
    ```

### Input Variables

- IOT_HUB_NAME - Name of your IoT Hub in your subscription. Don't use the FQDN name of the IoT Hub.
- SUBSCRIPTION - Subscription where your IoT Hub is located.
- RESOURCE_GROUP_NAME - Give a Resource Group name at your preference
- RESOURCE_GROUP_LOCATION - The Azure Data Center region where you want the Edge network and VM's to be created.
- VM_NAME - Give a VM name at your preference
- ADMIN_USER_NAME - The name you want to use as the admin account on the Edge VM's.
- UNIQUE_DNS_PREFIX - String of your choosing which will be used a prefix for the VM names on their public IP addresses.
- X509_CERT - Not required for running this repo to prepare edge VM, but required for next stage provisioning. the name only (not the full path) of your X.509 root CA cert.
- X509_KEY - Not required for running this repo to prepare edge VM, but required for next stage provisioning. the name only (not the full path) of your X.509 root CA key.
- SVS_PRI_ID - (optional) For service principle Azure login only. service principle app ID.
- SVS_PRI_PW - (optional) For service principle Azure login only. service principle password
- TENANT - (optional) For service principle Azure login only. Directory (tenant) ID of the service principle
- KEY_VAULT_NAME - provide azure key vault name that stores the x509 certs
- CERTIFICATE_NAME - provide cert name that's in the azure key vault
- DOWNLOAD_FILE_NAME - give a local file name to save the downloaded certs into.

### Optional Parameters

- -l    : Enable automatic Azure login mode with Service Principles. Default is manual Azure login with Azure account.
- -s    : Enable silent mode to redirect stdout from console. Default is false.
- -h : help

## Preparation Guide

### Create an Azure subscription

Try a free Azure subscription [here](https://azure.microsoft.com/en-us/free/).

### Create Azure IoT Hub

>Note:  If you already have an IoT Hub account, skip this step.

Follow instructions in this [tutorial](https://docs.microsoft.com/en-us/azure/iot-edge/quickstart-linux?view=iotedge-2020-11) to create your IoT Hub.

Understand more on IoT Hub [here](https://azure.microsoft.com/en-us/services/iot-hub/#overview).

### Install OpenSSL

If the edge VM/PC has csr permission issue, you will need to install and config your openssl to your PC Path via follow steps 1~5 in [here](https://linuxpip.org/install-openssl-linux/).

### Clean Up Resources

Delete the Resource Group together with all the resources it contains:

```bash
az group delete --name <resource-group-name>
```
