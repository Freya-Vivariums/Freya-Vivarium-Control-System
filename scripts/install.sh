#!/bin/bash

##
#   Install.sh
#   Installs the latest version of the Freya Vivarium Control System
#   on your device.
#
#   Copyright© 2025 Sanne “SpuQ” Santens
#   Released under the MIT License (see LICENSE.txt)
#
#  ----------------------------------------------------------------------------
#   Before changing this script
#  ----------------------------------------------------------------------------
#
#   The order is load-bearing. Node-RED reads its palette and its flow file once,
#   at startup, so it is started at the very end - after the node packages are
#   installed, after the hardware drivers are on the D-Bus, and after the default
#   flow is in place. Start it any earlier and the install still reports success
#   while Node-RED runs with an empty palette.
#
#   Node.js belongs to the whole device, not to this project. Edgeberry runs on
#   the same /usr/bin/node. Node.js is therefore installed when it is missing and
#   otherwise left exactly as found: a version that does not suit Node-RED is
#   reported and the install stops. Upgrading it here would change the runtime
#   underneath another application.
#
#   Versions are pinned, never discovered - see NODEREDVERSION below.
#
#   Steps report outcomes, not activity:
#
#     report_success                      prints [Success]
#     report_failure <output> [severity]  prints the reason indented on stderr;
#                                         'fatal' (default) exits 1, 'warning'
#                                         returns so the caller can continue
#     run_step <desc> <severity> <cmd..>  both of the above around one command
#
#   Never send a command's output to /dev/null. A bare "Failed!" cannot be
#   debugged on a device you are not sitting in front of.
#
#   'problems' counts failures that did not abort the install. The script exits
#   non-zero when it is not zero, so a partial install is never reported as a
#   success to whoever called it.
#
#   The hardware drivers are installed by separate scripts, downloaded from their
#   own releases. Their contract, which install_hardware_driver() relies on:
#
#     install.sh [--embedded]   --embedded tells them not to clear the screen or
#                               print their own closing banner; this script owns
#                               the screen and the verdict
#     exit 0                    installed
#     exit 1                    one or more steps failed
#     exit 2                    installed, but the device must reboot first
##

PROJECT=Freya
REPONAME=Freya-Vivarium-Control-System
REPOOWNER=Freya-Vivariums

APPDIR=/opt/${PROJECT}
SYSDCONF=freya-nodered-service.conf
# Repo names for the hardware drivers
ACTUATORDRIVERREPO=Freya-SenseAndDrive-Hardware-Cartridge
SENSORDRIVERREPO=Freya-Terra-Sensor
# Repo holding the default Node-RED flow
FLOWREPO=Freya-NodeRED-flow

##
#   Pinned versions
#   Pin deliberately, and bump deliberately. An unpinned install takes whatever
#   the registry serves that day, which is how this device ended up with a
#   Node-RED it could not start.
#
#   Node-RED 5.x requires Node.js >= 22.9. This device runs Debian's Node.js 20,
#   which is also what Edgeberry runs on, so the Node-RED 4.x line is the
#   supported combination here. Before raising this, check that the whole
#   palette - and Edgeberry - support the Node.js version the new line needs.
##
NODEREDVERSION=4.1.13

# Check if this script is running as root. If not, notify the user
# to run this script again as root and cancel the installtion process
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[0;31mUser is not root. Exit.\e[0m"
    echo -e "\e[0mRun this script again as root\e[0m"
    exit 1;
fi

##
#   Step reporting
#   Every step prints its outcome. A step that fails also prints the output
#   of the command that failed: "Failed!" on its own leaves the user with
#   nothing to debug, which is exactly the situation these helpers exist to
#   avoid. Commands are therefore captured, never discarded.
##

# Steps that report a failure without aborting are counted, so the closing
# message can tell the truth about what happened instead of always claiming
# success.
problems=0

# Set when a component needs this device rebooted before it can work.
REBOOT_REQUIRED=false

# Report a step that succeeded
report_success(){
    echo -e "\e[0;32m[Success]\e[0m"
}

# Report a step that failed. Takes the captured output of the failing command,
# and optionally the severity: 'fatal' (default) ends the installation,
# 'warning' reports and continues.
report_failure(){
    local output="$1"
    local severity="${2:-fatal}"

    if [ "${severity}" = "fatal" ]; then
        echo -e "\e[0;31mFailed! Exit.\e[0m"
    else
        echo -e "\e[0;33m[Failed]\e[0m"
    fi

    # Print the reason indented underneath the step it belongs to
    if [ -n "${output}" ]; then
        echo "${output}" | sed 's/^/    /' >&2
    fi

    if [ "${severity}" = "fatal" ]; then
        exit 1;
    fi
    return 0
}

# Run a single command as an installation step: print the description, run the
# command with its output captured, and report the outcome. Usage:
#   run_step "Installing jq" fatal apt install -y jq
run_step(){
    local description="$1"
    local severity="$2"
    shift 2
    local output

    echo -n -e "\e[0m${description} \e[0m"
    if output=$("$@" 2>&1); then
        report_success
        return 0
    fi
    report_failure "${output}" "${severity}"
    return 1
}

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

# Refresh the package index so subsequent apt installs use up-to-date sources.
# This takes a while, so announce it before starting instead of leaving the
# user staring at a silent screen. A stale package index is not fatal: the
# dependencies below may well already be installed, so warn and continue.
run_step "Refreshing the package index (this can take a minute)" warning \
    apt update

# Check for NodeJS. If it's not installed, install it.
#
# Node.js is a shared system component: Edgeberry runs on the same /usr/bin/node
# this project uses. So it is installed when missing and otherwise left exactly
# as it is - this installer never upgrades or replaces Node.js underneath
# another application. Where a version is not good enough, it says so and stops
# rather than "fixing" it.
echo -n -e "\e[0mChecking for NodeJS \e[0m"
if which node >/dev/null 2>&1; then
    echo -e "\e[0;32m[Installed] \e[0m$(node -v)";
else
    echo -e "\e[0;33m[Not installed] \e[0m";
    run_step "Installing Node using apt" fatal apt install -y nodejs
fi

# Check for NPM. If it's not installed, install it.
echo -n -e "\e[0mChecking for Node Package Manager (NPM) \e[0m"
if which npm >/dev/null 2>&1; then
    echo -e "\e[0;32m[Installed] \e[0m";
else
    echo -e "\e[0;33m[Not installed] \e[0m";
    run_step "Installing NPM using apt" fatal apt install -y npm
fi

# The version of Node-RED currently installed globally, read from its
# package.json. Never ask node-red itself: when it cannot run on the installed
# Node.js it prints an error and still exits 0, so 'node-red --version' reports
# neither a version nor a failure.
installed_nodered_version(){
    local root pkg
    root=$(npm root -g 2>/dev/null) || return 1
    pkg="${root}/node-red/package.json"
    [ -f "${pkg}" ] || return 1
    jq -r '.version // empty' "${pkg}" 2>/dev/null
}

# Install Node-RED from scratch using the official installer, which also creates
# the systemd service. No --node* flag is passed on purpose: those make the
# script add the NodeSource apt repository and reinstall Node.js, which would
# replace the Node.js that Edgeberry runs on. Without one it leaves Node.js
# alone, which is what this project wants.
install_nodered_from_scratch(){
    local installer output
    echo -n -e "\e[0mInstalling Node-RED ${NODEREDVERSION} \e[0m"
    # Download the installer to a file first. Piping a failed download straight
    # into bash succeeds on an empty script, which would report Node-RED as
    # installed when nothing happened at all.
    installer=$(mktemp)
    output=$( {
        set -e
        curl -fsL -o "${installer}" \
            https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered
        bash "${installer}" \
            --confirm-root \
            --confirm-install \
            --skip-pi \
            --nodered-version="${NODEREDVERSION}" \
            --restart
    } 2>&1 )
    local result=$?
    rm -f "${installer}"
    if [ ${result} -eq 0 ]; then
        report_success
    else
        report_failure "${output}"
    fi
}

# Check for Node-RED. Presence is not enough: it has to be the pinned version,
# because that is the version this project has been tested against and the one
# that runs on the Node.js already on this device.
echo -n -e "\e[0mChecking for Node-RED \e[0m"
current_nodered=$(installed_nodered_version)
if [ "${current_nodered}" = "${NODEREDVERSION}" ]; then
    echo -e "\e[0;32m[Installed] \e[0mv${current_nodered}";
elif [ -z "${current_nodered}" ]; then
    echo -e "\e[0;33m[Not installed] \e[0m";
    install_nodered_from_scratch
else
    # Present but not the pinned version. The systemd service already exists, so
    # replace just the package - re-running the official installer here would
    # touch far more of the system than needs touching.
    echo -e "\e[0;33m[Found v${current_nodered}, want v${NODEREDVERSION}] \e[0m";
    run_step "Installing Node-RED ${NODEREDVERSION}" fatal \
        npm install -g node-red@${NODEREDVERSION}
fi

# Node-RED states the Node.js version it needs. Check the one on this device
# satisfies it, rather than finding out from a service that crash-loops.
# Majors are compared, which is enough to catch the mismatch that matters
# without hand-rolling a semver parser.
# Note what this deliberately does not do: upgrade Node.js. It is shared with
# Edgeberry, so resolving a mismatch is a decision for a human, not a side
# effect of installing a vivarium.
echo -n -e "\e[0mChecking Node.js suits Node-RED \e[0m"
nodered_needs=$(jq -r '.engines.node // empty' "$(npm root -g)/node-red/package.json" 2>/dev/null)
node_major=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
needs_major=$(echo "${nodered_needs}" | grep -o '[0-9]\+' | head -1)
if [ -z "${needs_major}" ] || [ -z "${node_major}" ]; then
    # Nothing to compare against: report it rather than claiming a pass.
    echo -e "\e[0;33m[Unknown]\e[0m"
    echo -e "\e[0m    Could not determine the requirement (node-red wants '${nodered_needs:-?}', node reports '$(node -v 2>/dev/null)')\e[0m"
elif [ "${node_major}" -ge "${needs_major}" ]; then
    echo -e "\e[0;32m[Success]\e[0m"
else
    report_failure "Node-RED ${NODEREDVERSION} needs Node.js ${nodered_needs}, but this device has $(node -v).
Node.js is shared with Edgeberry on this device, so this installer will not
upgrade it. Either pin Node-RED to a release that supports Node.js ${node_major}
(NODEREDVERSION in this script), or upgrade Node.js deliberately after checking
that Edgeberry still works on the newer version."
fi

# Check for JQ (required by this script). If it's not installed,
# install it.
echo -n -e "\e[0mChecking for jq \e[0m"
if which jq >/dev/null 2>&1; then
    echo -e "\e[0;32m[Installed] \e[0m";
else
    echo -e "\e[0;33m[Not installed] \e[0m";
    run_step "Installing jq using apt" fatal apt install -y jq
fi

##
#   Application:
#   Look up and download the latest version from GitHub,
#   then put all the required files in their right place
#   to start the actual installation.
##

# Check for the latest release of the application using the GitHub API
echo -n -e "\e[0mGetting latest ${PROJECT} release info \e[0m"
latest_release=$(curl -H "Accept: application/vnd.github.v3+json" -s "https://api.github.com/repos/${REPOOWNER}/${REPONAME}/releases/latest")
# Check if this was successful (curl -s returns a JSON error body on failure,
# so verify the payload actually contains a release tag).
if [ -n "$latest_release" ] && echo "$latest_release" | jq -e '.tag_name' >/dev/null 2>&1; then
    report_success
else
    # The response body carries the actual reason (API rate limit exceeded,
    # repository not found, no internet connection, ...), so show it.
    report_failure "GitHub API: https://api.github.com/repos/${REPOOWNER}/${REPONAME}/releases/latest
Response was:
${latest_release:-(empty - no response from GitHub)}"
fi

# Get the asset download URL from the release info
echo -n -e "\e[0mGetting the latest ${PROJECT} release download URL \e[0m"
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
    report_success
else
    # Name what was looked for and what the release actually contains: a
    # release published without its tarball is otherwise indistinguishable
    # from a broken script.
    release_tag=$(echo "$latest_release" | jq -r '.tag_name')
    release_assets=$(echo "$latest_release" | jq -r '.assets[].name')
    report_failure "No asset matching '${REPONAME}-v<x>.<y>.<z>.tar.gz' in release ${release_tag}.
Assets in this release:
${release_assets:-(none - the release has no attached files)}"
fi

echo -n -e "\e[0mDownloading the application \e[0m"
# -f makes HTTP errors fail the command instead of silently saving an error
# page as if it were the tarball.
download_output=$(curl -fL \
    -H "Accept: application/octet-stream" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -o "repo.tar.gz" \
    "$asset_url" 2>&1)
# Check if the download was successful
if [ $? -eq 0 ] && [ -s "repo.tar.gz" ]; then
    report_success
else
    report_failure "Download URL: ${asset_url}
${download_output:-(downloaded file is empty)}"
fi

# Untar the application in the application folder
echo -n -e "\e[0mUnpacking the application \e[0m"
unpack_output=$( {
    set -e
    mkdir -p ${APPDIR}
    tar -xzf repo.tar.gz -C ${APPDIR}
} 2>&1 )
# Check if the last command succeeded
if [ $? -eq 0 ]; then
    report_success
else
    report_failure "Unpacking repo.tar.gz into ${APPDIR} failed:
${unpack_output}"
fi

# Cleanup the download tarball
rm -rf repo.tar.gz

##
#   Application:
#   Actually installing the application
##

# Install the application's systemd service mods for Node-RED
echo -e -n '\e[mInstalling Node-RED systemd service configuration \e[m'
systemd_output=$( {
    set -e
    # Make the directory for the config file and move the config file there
    mkdir -p /etc/systemd/system/nodered.service.d
    mv -f ${APPDIR}/config/${SYSDCONF} /etc/systemd/system/nodered.service.d/
    systemctl daemon-reload
    # Make sure Node-RED runs after a reboot. Starting it is deliberately left
    # until the end of this script: Node-RED reads its palette once at startup,
    # so it has to start after the nodes and the hardware drivers are in place.
    systemctl enable nodered.service
} 2>&1 )
if [ $? -eq 0 ]; then
    report_success
else
    # Node-RED's own journal explains a failed start far better than systemctl
    # does, so point at it rather than leaving the user to guess.
    report_failure "${systemd_output}
Run 'journalctl -u nodered -n 50' for the service log." warning
    problems=$((problems+1))
fi

# Install package dependencies
echo -n -e "\e[0mInstalling dependencies \e[0m"
npm_output=$(npm install --prefix ${APPDIR}/nodered 2>&1)
# Check if the last command succeeded
if [ $? -eq 0 ]; then
    report_success
else
    report_failure "npm install --prefix ${APPDIR}/nodered
${npm_output}"
fi

# Register the application with Edgeberry
# Edgeberry owns nginx and proxies /application/* to the app port,
# so this must succeed for the UI to be reachable.
echo -n -e "\e[0mRegistering ${PROJECT} with Edgeberry \e[0m"
register_output=$(edgeberry --register-application ${APPDIR} 2>&1)
if [ $? -eq 0 ]; then
    report_success
else
    report_failure "edgeberry --register-application ${APPDIR}
${register_output}"
fi

##
#   Install the Hardware drivers
#   These are complete installers in their own right: they print their own
#   progress, so their output is left on screen instead of being captured.
#   They are run with --embedded, which stops them clearing this script's
#   output off the screen and announcing an installation that is not finished.
##

# Download and run one of the hardware driver installers.
#   $1 = repository name, $2 = human readable name for the messages
install_hardware_driver(){
    local repo="$1"
    local description="$2"
    local url="https://github.com/Freya-Vivariums/${repo}/releases/latest/download/install.sh"
    local installer

    echo ""
    echo -e "\e[0mInstalling the ${description} \e[0m"

    installer=$(mktemp)
    if ! wget -q -O "${installer}" "${url}" || [ ! -s "${installer}" ]; then
        echo -e "\e[0;33mCould not download the ${description} installer from\e[0m" >&2
        echo -e "\e[0;33m  ${url}\e[0m" >&2
        rm -f "${installer}"
        problems=$((problems+1))
        return 1
    fi

    chmod +x "${installer}"
    bash "${installer}" --embedded
    local result=$?
    rm -f "${installer}"

    if [ ${result} -eq 0 ]; then
        echo -e "\e[0;32mThe ${description} was installed.\e[0m"
        return 0
    fi

    # A driver installer exits 2 when it installed correctly but the device has
    # to be rebooted before the hardware is usable - enabling the I2C bus, for
    # instance. That is not a failure, but it must not be swallowed either.
    if [ ${result} -eq 2 ]; then
        echo -e "\e[0;32mThe ${description} was installed.\e[0m"
        REBOOT_REQUIRED=true
        return 0
    fi

    echo -e "\e[0;33mThe ${description} installer failed (see its output above).\e[0m" >&2
    problems=$((problems+1))
    return 1
}

install_hardware_driver "${ACTUATORDRIVERREPO}" "actuator driver"
install_hardware_driver "${SENSORDRIVERREPO}" "sensor driver"

##
#   Default flow
#   Install the default Freya flow, but only when this device does not have one
#   yet. On an update the flow on the device belongs to the user and is very
#   likely edited, so it must never be overwritten. The flow is optional: if the
#   flow repository has no release asset, the installation carries on and the
#   user imports the flow through the editor.
##
FLOWFILE=${APPDIR}/nodered/flows/Freya_flows.json
FLOWURL=https://github.com/Freya-Vivariums/${FLOWREPO}/releases/latest/download/Freya_flows.json

echo -n -e "\e[0mInstalling the default flow \e[0m"
if [ -s "${FLOWFILE}" ]; then
    # Not a failure: this is an update, and the flow on the device is the user's.
    echo -e "\e[0;32m[Kept the existing flow]\e[0m"
else
    flow_download=$(mktemp)
    if ! curl -fsL -o "${flow_download}" "${FLOWURL}"; then
        # No published flow to install. The system works without one, so this
        # is not a problem - but the user has to know the vivarium will not
        # control anything until a flow is imported.
        echo -e "\e[0;33m[Not available]\e[0m"
        echo -e "\e[0m    No flow release asset at ${FLOWURL}\e[0m"
        echo -e "\e[0m    Import the flow through the Node-RED editor instead, see\e[0m"
        echo -e "\e[0m    https://github.com/Freya-Vivariums/${FLOWREPO}\e[0m"
    # The -s test is not redundant: jq reads an empty file as "no input" and
    # exits 0, so an empty download would otherwise pass as a valid flow.
    elif [ ! -s "${flow_download}" ] || ! jq -e 'type == "array" and length > 0' "${flow_download}" >/dev/null 2>&1; then
        # A corrupt flow file stops Node-RED from starting at all. Refuse to
        # install one, rather than break the editor the user needs to fix it.
        report_failure "The downloaded flow is not a valid Node-RED flow file.
Downloaded from ${FLOWURL}" warning
        problems=$((problems+1))
    else
        flow_output=$( {
            set -e
            mkdir -p "$(dirname "${FLOWFILE}")"
            mv -f "${flow_download}" "${FLOWFILE}"
            chmod 644 "${FLOWFILE}"
            # Match the userDir's ownership so Node-RED can still rewrite the
            # flow on deploy if the service is ever run as a non-root user.
            chown -R "$(stat -c '%U:%G' ${APPDIR}/nodered)" "$(dirname "${FLOWFILE}")"
        } 2>&1 )
        if [ $? -eq 0 ]; then
            report_success
        else
            report_failure "${flow_output}" warning
            problems=$((problems+1))
        fi
    fi
    rm -f "${flow_download}"
fi

##
#   Start Node-RED
#   Last, so that it starts with the freshly installed nodes in its palette,
#   the default flow in place and the hardware drivers already on the bus.
#   Node-RED reads its palette and flow once at startup, so starting it any
#   earlier leaves it running without them until something restarts it.
##
echo ""
echo -n -e "\e[0mStarting Node-RED \e[0m"
# Record where to start reading the journal, before anything is restarted.
nodered_since=$(date '+%Y-%m-%d %H:%M:%S')
nodered_output=$(systemctl restart nodered.service 2>&1)
if [ $? -eq 0 ]; then
    report_success
else
    report_failure "${nodered_output}
Run 'journalctl -u nodered -n 50' for the service log." warning
    problems=$((problems+1))
fi

# 'systemctl restart' returns 0 as soon as systemd has spawned the process. It
# says nothing about whether Node-RED survived: a crash-looping service reports
# itself as "active (running)" for as long as each attempt lasts. So wait for
# Node-RED to say, itself, that it got as far as running the flow.
#
# This is the check that catches what the individual steps cannot - a palette
# that will not load, a flow referring to a node that is not installed, a
# Node.js it cannot run on. It does not need to know which of those went wrong.
echo -n -e "\e[0mWaiting for Node-RED to start the flows \e[0m"
# Generous: loading a large palette on a cold Raspberry Pi is slow, and calling
# a working install broken is worse than waiting a little longer.
NODEREDSTARTTIMEOUT=90
nodered_started=false
for _ in $(seq 1 $((NODEREDSTARTTIMEOUT / 2))); do
    if journalctl -u nodered.service --since "${nodered_since}" 2>/dev/null | grep -q "Started flows"; then
        nodered_started=true
        break
    fi
    sleep 2
done

if [ "${nodered_started}" = true ]; then
    report_success
else
    report_failure "Node-RED did not report 'Started flows' within ${NODEREDSTARTTIMEOUT} seconds.
The last of its log:
$(journalctl -u nodered.service --since "${nodered_since}" --no-pager 2>/dev/null | tail -15)" warning
    problems=$((problems+1))
fi

##
#   Finish installation
##
echo ""
if [ "${REBOOT_REQUIRED}" = true ]; then
    echo -e "\e[0;33mThis device must be rebooted before all of the hardware works.\e[0m"
    echo -e "\e[0;33mReboot it with:  sudo reboot\e[0m"
    echo ""
fi

if [ ${problems} -eq 0 ]; then
    echo -e "The \033[1m${PROJECT}\033[0m was successfully installed!"
    echo ""
    # Remove this script
    rm -- "$0"
    exit 0;
fi

# Something failed without aborting the installation. Say so, and exit non-zero
# so a calling script sees it too.
echo -e "\e[0;33mThe ${PROJECT} installation finished with ${problems} problem(s).\e[0m" >&2
echo -e "\e[0;33mScroll up for the details of each failed step.\e[0m" >&2
echo ""
# Remove this script
rm -- "$0"

exit 1;
