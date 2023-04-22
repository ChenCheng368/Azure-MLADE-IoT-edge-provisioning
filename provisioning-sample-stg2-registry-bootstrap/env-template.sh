# edge environment
export IOT_HUB_NAME=""  #provide a valid iothub
export SUBSCRIPTION=""  #provide a valid subscription
export RESOURCE_GROUP_NAME=""   #give a RG name at your preference
export RESOURCE_GROUP_LOCATION=""   #give a RG location at your preference
export VM_NAME=""   #give a VM name at your preference
export ADMIN_USER_NAME=""   #give a user name for the edge VM at your preference
export UNIQUE_DNS_PREFIX=""  #give a prefix name at your preference
export DNS_FOR_PUBLIC_IP=${UNIQUE_DNS_PREFIX}"-"${VM_NAME} #edge VM DNS name for public IP. It uses default value '${UNIQUE_DNS_PREFIX}"-"${VM_NAME}' if not assign any name
export X509_CERT=""   #provide x.509 cert root ca cert name
export X509_KEY=""   #provide x.509 cert root ca key name
export SVS_PRI_ID=   #provide service principle app ID. Do not put as string
export SVS_PRI_PW=   #provide service principle password. Do not put as string
export TENANT=   #provide Directory (tenant) ID of the service principle. Do not put as string

export KEY_VAULT_NAME=  # provide azure key vault name that stores the x509 certs
export CERTIFICATE_NAME= # provide cert name that's in the azure key vault
export DOWNLOAD_FILE_NAME= # give a local file name to save the downloaded certs into.

