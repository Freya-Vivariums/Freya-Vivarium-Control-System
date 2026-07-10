#!/bin/bash

##
#   Uninstall.sh
#   Removes the Freya Vivarium Control System from your device.
#   Runs the uninstall script of every installed component found in the
#   project directory, then cleans up everything install.sh installed.
#   System dependencies (NodeJS, NPM, Node-RED, jq) are intentionally kept.
#
#   Copyright© 2025 Sanne “SpuQ” Santens
#   Released under the MIT License (see LICENSE.txt)
##

PROJECT=Freya
APPDIR=/opt/${PROJECT}
SYSDCONF=freya-nodered-service.conf

# Check if this script is running as root. If not, notify the user
# to run this script again as root and cancel the uninstallation process
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[0;31mUser is not root. Exit.\e[0m"
    echo -e "\e[0mRun this script again as root\e[0m"
    exit 1;
fi

# Continue with a clean screen
clear;

echo -e "\e[0mUninstalling \033[1m${PROJECT}\033[0m\e[0m"
echo ""

##
#   Components:
#   Look through the project directory's subdirectories and run the
#   uninstall script of any component that provides one, one by one.
##

if [ -d "${APPDIR}" ]; then
    for component in "${APPDIR}"/*/; do
        # Skip if the glob didn't match anything (no subdirectories)
        [ -d "${component}" ] || continue

        # Look for a component uninstall script (uninstall.sh or uninstall)
        uninstaller=""
        if [ -f "${component}uninstall.sh" ]; then
            uninstaller="${component}uninstall.sh"
        elif [ -f "${component}uninstall" ]; then
            uninstaller="${component}uninstall"
        fi

        # If this component has no uninstaller, move on
        [ -n "${uninstaller}" ] || continue

        echo -n -e "\e[0mUninstalling component '$(basename "${component}")' \e[0m"
        bash "${uninstaller}" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "\e[0;32m[Success]\e[0m"
        else
            echo -e "\e[0;33m[Failed]\e[0m";
        fi
    done
else
    echo -e "\e[0;33m${APPDIR} not found, nothing to uninstall from components.\e[0m"
fi

##
#   System service:
#   Remove the Node-RED systemd drop-in that install.sh added and reload
#   the service so it returns to its default configuration. Node-RED itself
#   is a system dependency and is left installed.
##

echo -n -e "\e[0mRemoving Node-RED systemd service configuration \e[0m"
if [ -f "/etc/systemd/system/nodered.service.d/${SYSDCONF}" ]; then
    rm -f "/etc/systemd/system/nodered.service.d/${SYSDCONF}"
    # Remove the drop-in directory if it is now empty
    rmdir --ignore-fail-on-non-empty /etc/systemd/system/nodered.service.d 2>/dev/null
    systemctl daemon-reload
    # Restart Node-RED so it picks up the default configuration
    systemctl restart nodered.service > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33m[Failed]\e[0m";
    fi
else
    echo -e "\e[0;33m[Not found]\e[0m"
fi

##
#   Application:
#   Remove the application directory installed by install.sh.
##

echo -n -e "\e[0mRemoving the application directory (${APPDIR}) \e[0m"
if [ -d "${APPDIR}" ]; then
    rm -rf "${APPDIR}"
    if [ $? -eq 0 ]; then
        echo -e "\e[0;32m[Success]\e[0m"
    else
        echo -e "\e[0;33m[Failed]\e[0m";
    fi
else
    echo -e "\e[0;33m[Not found]\e[0m"
fi

##
#   Finish uninstallation
##
echo ""
echo -e "The \033[1m${PROJECT}\033[0m was successfully uninstalled!"
echo -e "\e[0mNote: system dependencies (NodeJS, NPM, Node-RED, jq) were left installed.\e[0m"
echo ""
# Remove this script
rm -- "$0"

exit 0;
