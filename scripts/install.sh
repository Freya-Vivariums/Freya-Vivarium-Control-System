#!/bin/bash

##
#   Install.sh
#   Installs the latest version of the Freya Vivarium Control System
#   on your device.
#
#   Copyright© 2025 Sanne “SpuQ” Santens
#   Released under the MIT License (see LICENSE.txt)
##

PROJECT=Freya
REPONAME=${PROJECT}
REPOOWNER=Freya-Vivariums

APPDIR=/opt/${PROJECT}
SYSDCONF=freya-nodered-service.conf
# Repo names for the hardware drivers
ACTUATORDRIVERREPO=Freya-actuators-driver
SENSORDRIVERREPO=Freya-sensor-driver

# Check if this script is running as root. If not, notify the user
# to run this script again as root and cancel the installtion process
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[0;31mUser is not root. Exit.\e[0m"
    echo -e "\e[0mRun this script again as root\e[0m"
    exit 1;
fi

# Continue with a clean screen
clear;

# Display a fancy logo
echo "                  +                                                                               "
echo "                 +++                                                                              "
echo "        ==       ++++                                                                             "
echo "        =====   =+++++                                                                            "
echo "        ======= ++++++      %%%%%%%%%%%  %%%%%%%%%%    %%%%%%%%%%%%%%%%%     %%%%%    %%%%%  TM   "
echo "        ========+++++++     %%%%%%%%%%%  %%%%%%%%%%%%  %%%%%%%%%%%% %%%%     %%%%    %%%%%%       "
echo "   -----=======++++++++     %%%%         %%%%   %%%%%  %%%%%         %%%%   %%%%    %%%%%%%%      "
echo "    ---- ======+++++++++    %%%%         %%%%    %%%%  %%%%%          %%%% %%%%     %%%% %%%%     "
echo "    -----======+++++++++    %%%%%%%%%%   %%%%%%%%%%%%  %%%%%%%%%%      %%%%%%%     %%%%  %%%%     "
echo "     -----=====+++++++++    %%%%%%%%%%   %%%%%%%%%%    %%%%%%%%%%      %%%%%%     %%%%%%%%%%%%    "
echo "     +----=====+++++++++    %%%%         %%%%%%%%%%    %%%%%            %%%%%     %%%%%%%%%%%%%   "
echo "  ++**+ ----====++++++++    %%%%         %%%%  %%%%%   %%%%%            %%%%%    %%%%%%%%%%%%%%   "
echo " *******+----====+++++++    %%%%         %%%%   %%%%%  %%%%%%%%%%%%     %%%%%   %%%%%       %%%%  "
echo " +*+******+----===+++++     %%%%         %%%%    %%%%% %%%%%%%%%%%%     %%%%%   %%%%        %%%%% "
echo "   ********+*+=- = +++                                                                            "
echo "      ***********++                                                                               "
echo "         +***++*                                                                                  "
echo ""

##
#   Dependencies
#   Install system dependencies for this service
#   and installation script to work correctly
##

# Check for NodeJS. If it's not installed, install it.
echo -n -e "\e[0mChecking for NodeJS \e[0m"
if which node >/dev/null 2>&1; then 
    echo -e "\e[0;32m[Installed] \e[0m";
else 
    echo -e "\e[0;33m[Not installed] \e[0m";
    echo -n -e "\e[0mInstalling Node using apt \e[0m";
    apt install -y nodejs > /dev/null 2>&1;
    # Check if the last command succeeded
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33mFailed! Exit.\e[0m";
        exit 1;
    fi
fi

# Check for NPM. If it's not installed, install it.
echo -n -e "\e[0mChecking for Node Package Manager (NPM) \e[0m"
if which npm >/dev/null 2>&1; then 
    echo -e "\e[0;32m[Installed] \e[0m"; 
else 
    echo -e "\e[0;33m[Not installed] \e[0m";
    echo -n -e "\e[0mInstalling NPM using apt \e[0m";
    apt install -y npm > /dev/null 2>&1;
    # Check if the last command succeeded
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33mFailed! Exit.\e[0m";
        exit 1;
    fi
fi

# Check for Node-RED. If it's not installed, install it.
echo -n -e "\e[0mChecking for Node-RED \e[0m"
if which node-red >/dev/null 2>&1; then 
    echo -e "\e[0;32m[Installed] \e[0m"; 
else 
    echo -e "\e[0;33m[Not installed] \e[0m";
    echo -n -e "\e[0mInstalling Node-RED \e[0m";
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)  \
    --confirm-root \
    --confirm-install \
    --skip-pi \
    --restart \
    #>/dev/null 2>&1;
    # Check if the last command succeeded
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33mFailed! Exit.\e[0m";
        exit 1;
    fi
fi

# Check for JQ (required by this script). If it's not installed,
# install it.
echo -n -e "\e[0mChecking for jq \e[0m"
if which jq >/dev/null 2>&1; then  
    echo -e "\e[0;32m[Installed] \e[0m"; 
else 
    echo -e "\e[0;33m[Not installed] \e[0m";
    echo -n -e "\e[0mInstalling jq using apt \e[0m";
    apt install -y jq > /dev/null 2>&1
    # Check if the last command succeeded
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33mFailed! Exit.\e[0m";
        exit 1;
    fi
fi

##
#   Application:
#   Look up and download the latest version from GitHub,
#   then put all the required files in their right place
#   to start the actual installation.
##

# Check for the latest release of the application using the GitHub API
echo -n -e "\e[0mGetting latest ${PROJECT} ${COMPONENT} release info \e[0m"
latest_release=$(curl -H "Accept: application/vnd.github.v3+json" -s "https://api.github.com/repos/${REPOOWNER}/${REPONAME}/releases/latest")
# Check if this was successful
if [ -n "$latest_release" ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33mFailed to get latest ${PROJECT} ${COMPONENT} release info! Exit.\e[0m";
    exit 1;
fi
# Get the asset download URL from the release info
echo -n -e "\e[0mGetting the latest ${PROJECT} ${COMPONENT} release download URL \e[0m"
#asset_url=$(echo "$latest_release" | jq -r `.assets[] | select(.name | test("${REPONAME}-v[0-9]+\\.[0-9]+\\.[0-9]+\\.tar\\.gz")) | .url`)
# assume $REPONAME is already set, and you've downloaded "$latest_release" via GitHub API
asset_url=$(
  echo "$latest_release" \
    | jq -r \
        --arg re "${REPONAME}-v[0-9]+\\.[0-9]+\\.[0-9]+\\.tar\\.gz" \
        '.assets[]
         | select(.name | test($re))
         | .browser_download_url'
)
# If we have an asset URL, download the tarball
if [ -n "$asset_url" ]; then
    #echo -e "\e[0;32mURL:\e[0m ${asset_url}";
    echo -e "\e[0;32m[Success]\e[0m"; 
    echo -n -e "\e[0mDownloading the application \e[0m"
    curl -L \
    -H "Accept: application/octet-stream" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -o "repo.tar.gz" \
    "$asset_url" > /dev/null 2>&1
    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33mFailed! Exit.\e[0m";
        exit 1;
    fi
else
    echo -e "\e[0;33mFailed! Exit.\e[0m";
    exit 1;
fi

# Untar the application in the application folder
echo -n -e "\e[0mUnpacking the application \e[0m"
mkdir -p ${APPDIR}  > /dev/null 2>&1;
tar -xvzf repo.tar.gz -C ${APPDIR} > /dev/null 2>&1
# Check if the last command succeeded
if [ $? -eq 0 ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33mFailed! Exit.\e[0m";
    exit 1;
fi

# Cleanup the download tarball
rm -rf repo.tar.gz

##
#   Application:
#   Actually installing the application
##

# Install the application's systemd service mods for Node-RED
echo -e -n '\e[mInstalling Node-RED systemd service configuration \e[m'
# Make the directory for the config file and move the config file there
mkdir -p /etc/systemd/system/nodered.service.d
mv -f ${APPDIR}/config/${SYSDCONF} /etc/systemd/system/nodered.service.d/
systemctl daemon-reload
# Make sure Node-RED runs after a reboot
systemctl enable nodered.service
# Restart the Node-RED service
systemctl restart nodered.service
if [ $? -eq 0 ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33m[Failed]\e[0m";
fi

# Install package dependencies
echo -n -e "\e[0mInstalling dependencies \e[0m"
npm install --prefix ${APPDIR}/nodered > /dev/null 2>&1
# Check if the last command succeeded
if [ $? -eq 0 ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33mFailed! Exit.\e[0m";
    exit 1;
fi

##
#   Install the Hardware drivers
##

# Actuators
wget -O install.sh https://github.com/Freya-Vivariums/${ACTUATORDRIVERREPO}/releases/latest/download/install.sh;
chmod +x ./install.sh;
bash ./install.sh;
if [ $? -eq 0 ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33mFailed!\e[0m";
fi

# Sensor
wget -O install.sh https://github.com/Freya-Vivariums/${SENSORDRIVERREPO}/releases/latest/download/install.sh;
chmod +x ./install.sh;
bash ./install.sh;
if [ $? -eq 0 ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    echo -e "\e[0;33mFailed!\e[0m";
fi

##
#   Finish installation
##
echo ""
echo -e "The \033[1m${PROJECT}\033[0m was successfully installed!"
echo ""
# Remove this script
rm -- "$0"

exit 0;