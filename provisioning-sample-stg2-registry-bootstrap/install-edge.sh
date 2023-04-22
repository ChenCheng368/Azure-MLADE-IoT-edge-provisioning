# Add IoT Edge package repository and then add the Microsoft package signing key to your list of trusted keys
curl https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list > ./microsoft-prod.list
sudo cp ./microsoft-prod.list /etc/apt/sources.list.d/
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo cp ./microsoft.gpg /etc/apt/trusted.gpg.d/

# Install the Moby engine.
sudo apt-get update
sudo apt-get install moby-engine -y

# Install the IoT Edge runtime
sudo apt-get install aziot-edge -y

# Install root CA cert 
sudo apt-get install zip -y
cd /home/${ADMIN_USER_NAME}
unzip ${DEVICE_ID}.zip 
sudo ./install.sh
