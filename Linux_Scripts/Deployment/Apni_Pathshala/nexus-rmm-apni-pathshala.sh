#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo "ERROR: Must be run as root"
    exit 1
fi

# Set the hostname of the machine as the serial number of the machine
serial_number=$(dmidecode --string system-serial-number)
hostnamectl set-hostname "${serial_number}" --static --pretty

# update /etc/hosts file to include the hostname like this:
sed -i "s/^127.0.1.1.*/127.0.1.1 ${serial_number} ${serial_number}.local/" /etc/hosts

# Create Scogo IT Support user account
echo "Creating Scogo IT Support user account..."
useradd -c "Scogo IT Support" -m -s /bin/bash scogo
echo 'scogo:Sc090@1947' | chpasswd
usermod -aG sudo,adm,cdrom,dip,plugdev,video scogo
echo 'scogo ALL=(ALL) ALL' | tee /etc/sudoers.d/scogo && chmod 0440 /etc/sudoers.d/scogo

# Disable Wayland in GDM3 if it exists
if [ -f /etc/gdm3/custom.conf ]; then
    echo "Disabling Wayland in GDM3..."
    sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
    
    # Restart GDM3 service if it's active
    if systemctl is-active gdm3 >/dev/null 2>&1; then
        echo "Restarting GDM3 service..."
        systemctl restart gdm3
    fi
fi

# Restart systemd-logind service
echo "Restarting systemd-logind service..."
systemctl restart systemd-logind

HAS_SYSTEMD=$(ps --no-headers -o comm 1)
if [ "${HAS_SYSTEMD}" != 'systemd' ]; then
    echo "This install script only supports systemd"
    echo "Please install systemd or manually create the service using your systems's service manager"
    exit 1
fi

if [[ $DISPLAY ]]; then
    echo "ERROR: Display detected. Installer only supports running headless, i.e from ssh."
    echo "If you cannot ssh in then please run 'sudo systemctl isolate multi-user.target' to switch to a non-graphical user session and run the installer again."
    echo "If you are already running headless, then you are probably running with X forwarding which is setting DISPLAY, if so then simply run"
    echo "unset DISPLAY"
    echo "to unset the variable and then try running the installer again"
    exit 1
fi

DEBUG=0
INSECURE=0
NOMESH=0

agentDL='https://agents.tacticalrmm.com/api/v2/agents/?version=2.8.0&arch=amd64&token=e66816de-6785-4ce5-9529-d2cd8ec3892d&plat=linux&api=nexus-api.iceberg.scogo.ai'
meshDL='https://nexus-mesh.iceberg.scogo.ai/meshagents?id=93tgSDrhfs@iQIDchqKfQzINb9j29GnxzWAc4L2CyYFpX7sJTectrLJ4VLhsUjqc&installflags=2&meshinstall=6'

apiURL='https://nexus-api.iceberg.scogo.ai'
token='212a5cccae14f3c02e628594a60f476d5d8ae79aeafb788be097222f9601ee98'
clientID='2'
siteID='8'
agentType='workstation'
proxy=''

agentBinPath='/usr/local/bin'
binName='tacticalagent'
agentBin="${agentBinPath}/${binName}"
agentConf='/etc/tacticalagent'
agentSvcName='tacticalagent.service'
agentSysD="/etc/systemd/system/${agentSvcName}"
agentDir='/opt/tacticalagent'
meshDir='/opt/tacticalmesh'
meshSystemBin="${meshDir}/meshagent"
meshSvcName='meshagent.service'
meshSysD="/lib/systemd/system/${meshSvcName}"

deb=(ubuntu debian raspbian kali linuxmint)
rhe=(fedora rocky centos rhel amzn arch opensuse)

set_locale_deb() {
    locale-gen "en_US.UTF-8"
    localectl set-locale LANG=en_US.UTF-8
    . /etc/default/locale
}

set_locale_rhel() {
    localedef -c -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1
    localectl set-locale LANG=en_US.UTF-8
    . /etc/locale.conf
}

RemoveOldAgent() {
    if [ -f "${agentSysD}" ]; then
        systemctl disable ${agentSvcName}
        systemctl stop ${agentSvcName}
        rm -f "${agentSysD}"
        systemctl daemon-reload
    fi

    if [ -f "${agentConf}" ]; then
        rm -f "${agentConf}"
    fi

    if [ -f "${agentBin}" ]; then
        rm -f "${agentBin}"
    fi

    if [ -d "${agentDir}" ]; then
        rm -rf "${agentDir}"
    fi
}

InstallMesh() {
    if [ -f /etc/os-release ]; then
        distroID=$(
            . /etc/os-release
            echo $ID
        )
        distroIDLIKE=$(
            . /etc/os-release
            echo $ID_LIKE
        )
        if [[ " ${deb[*]} " =~ " ${distroID} " ]]; then
            set_locale_deb
        elif [[ " ${deb[*]} " =~ " ${distroIDLIKE} " ]]; then
            set_locale_deb
        elif [[ " ${rhe[*]} " =~ " ${distroID} " ]]; then
            set_locale_rhel
        else
            set_locale_rhel
        fi
    fi

    meshTmpDir='/root/meshtemp'
    mkdir -p $meshTmpDir

    meshTmpBin="${meshTmpDir}/meshagent"
    wget --no-check-certificate -q -O ${meshTmpBin} ${meshDL}
    chmod +x ${meshTmpBin}
    mkdir -p ${meshDir}
    env LC_ALL=en_US.UTF-8 LANGUAGE=en_US XAUTHORITY=foo DISPLAY=bar ${meshTmpBin} -install --installPath=${meshDir}
    sleep 1
    rm -rf ${meshTmpDir}
}

RemoveMesh() {
    if [ -f "${meshSystemBin}" ]; then
        env XAUTHORITY=foo DISPLAY=bar ${meshSystemBin} -uninstall
        sleep 1
    fi

    if [ -f "${meshSysD}" ]; then
        systemctl stop ${meshSvcName} >/dev/null 2>&1
        systemctl disable ${meshSvcName} >/dev/null 2>&1
        rm -f ${meshSysD}
    fi

    rm -rf ${meshDir}
    systemctl daemon-reload
}

Uninstall() {
    RemoveMesh
    RemoveOldAgent
}

if [ $# -ne 0 ] && [[ $1 =~ ^(uninstall|-uninstall|--uninstall)$ ]]; then
    Uninstall
    # Remove the current script
    rm "$0"
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -debug | --debug | debug) DEBUG=1 ;;
    -insecure | --insecure | insecure) INSECURE=1 ;;
    -nomesh | --nomesh | nomesh) NOMESH=1 ;;
    *)
        echo "ERROR: Unknown parameter: $1"
        exit 1
        ;;
    esac
    shift
done

RemoveOldAgent

echo "Downloading tactical agent..."
wget -q -O ${agentBin} "${agentDL}"
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to download tactical agent"
    exit 1
fi
chmod +x ${agentBin}

MESH_NODE_ID=""

if [[ $NOMESH -eq 1 ]]; then
    echo "Skipping mesh install"
else
    if [ -f "${meshSystemBin}" ]; then
        RemoveMesh
    fi
    echo "Downloading and installing mesh agent..."
    InstallMesh
    sleep 2
    echo "Getting mesh node id..."
    MESH_NODE_ID=$(env XAUTHORITY=foo DISPLAY=bar ${agentBin} -m nixmeshnodeid)
fi

if [ ! -d "${agentBinPath}" ]; then
    echo "Creating ${agentBinPath}"
    mkdir -p ${agentBinPath}
fi

INSTALL_CMD="${agentBin} -m install -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token}"

if [ "${MESH_NODE_ID}" != '' ]; then
    INSTALL_CMD+=" --meshnodeid ${MESH_NODE_ID}"
fi

if [[ $DEBUG -eq 1 ]]; then
    INSTALL_CMD+=" --log debug"
fi

if [[ $INSECURE -eq 1 ]]; then
    INSTALL_CMD+=" --insecure"
fi

if [ "${proxy}" != '' ]; then
    INSTALL_CMD+=" --proxy ${proxy}"
fi

eval ${INSTALL_CMD}

tacticalsvc="$(
    cat <<EOF
[Unit]
Description=Tactical RMM Linux Agent

[Service]
Type=simple
ExecStart=${agentBin} -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
)"
echo "${tacticalsvc}" | tee ${agentSysD} >/dev/null

systemctl daemon-reload
systemctl enable ${agentSvcName}
systemctl start ${agentSvcName}

