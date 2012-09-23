#!/bin/bash
#############################################################################
# Setup menu for Software Gateway
#############################################################################
#
#

SSGNODE="default"
export SSGNODE

# Source profile for standard environment
cd `dirname $0`
. ../etc/profile

CONFWIZARD="${SSG_HOME}/config/ssgconfig.sh"

nojava() {
    echo "Please ensure \"java\" is in the PATH, set JAVA_HOME or run with --jdk option."
    exit 11
}

confirmedMessage() {
    echo "${1}"
    echo "Press [Enter] to continue";
    read;
}

#
# Process script args
#
while (( "$#" )); do
    if [ "$1" == "--jdk" ]; then
        shift
        if [ -f "$1" ] && [ -x "$1" ] ; then
            JAVA_HOME="$(dirname $1)/.."
        elif [ -x "$1/bin/java" ]; then
            JAVA_HOME="$1"
        else
            nojava
        fi
    fi
    shift
done

#
# Validate Java settings
#
if [ ! -z "${JAVA_HOME}" ] ; then
    if [ ! -x "${JAVA_HOME}/bin/java" ] ; then
        nojava
    fi
elif [ ! -z "${SSG_JAVA_HOME}" ] ; then
    JAVA_HOME="${SSG_JAVA_HOME}"    
else
    JAVA="$(which java 2>/dev/null)"
    if [ $? -ne 0 ] ; then
        nojava
    else
        JAVA_HOME="$(dirname ${JAVA})/.."
    fi
fi
export JAVA_HOME;

export SSG_JAVA_HOME="${JAVA_HOME}"
ensure_JDK 1.6

#
# Menu
#
isValid="n"
while [ "$isValid" != "y" ]
do
    clear
    echo "Layer 7 Gateway Software configuration menu."
    echo ""
    echo "What would you like to do?"
    echo ""
    echo " 1) Upgrade the Layer 7 Gateway database"
    echo " 2) Configure the Layer 7 Gateway"
    echo " 3) Display the current Layer 7 Gateway configuration"
    echo " 4) Change the Layer 7 Gateway Cluster Passphrase"
    echo " 5) Change the Master Passphrase"
    echo " X) Exit"
    echo ""
    echo -n "Please make a selection: "
    read choice

    case $choice in
            1)
                clear;
                (${CONFWIZARD} -databaseUgrade);
                confirmedMessage ""
                clear;;
            2)
                clear;
                (${CONFWIZARD} auto software);
                STATUS=$?
                if [ $STATUS -eq 5 ] ; then
                  confirmedMessage "Unexpected error in configuration service."
                else
                  confirmedMessage ""
                fi
                clear;;
            3)
                clear;
                (${CONFWIZARD} show software);
                STATUS=$?
                if [ $STATUS -eq 2 ] ; then
                  confirmedMessage "Node is not yet configured."
                elif [ $STATUS -eq 5 ] ; then
                  confirmedMessage "Unexpected error in configuration service."
                elif [ $STATUS -ne 0 ] ; then
                  confirmedMessage ""
                fi
                clear;;
            4)
                clear;
                (${CONFWIZARD} -changeClusterPassphrase);
                confirmedMessage ""
                clear;;
            5)
                clear;
                (${CONFWIZARD} -changeMasterPassphrase);
                confirmedMessage ""
                clear;;
            x|X)
                clear;
                isValid="y";
                clear;;
            *)
                clear;
                isValid="n";
                confirmedMessage "That is not a valid selection";
                read;
                clear;;
    esac
    exit
done






