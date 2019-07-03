#!/bin/bash
#
# Copyright (C) hsj51 <hrutvikjagtap51@gmail.com>
# SPDX-License-Identifier: GPL-v3.0-only
#

# Prints a formatted header; used for outlining
function echoText() {
    RED="\033[01;31m"
    RST="\033[0m"

    echo -e "${RED}"
    echo -e "====$( for i in $(seq ${#1}); do echo -e "=\c"; done )===="
    echo -e "==  ${1}  =="
    echo -e "====$( for i in $(seq ${#1}); do echo -e "=\c"; done )===="
    echo -e "${RST}"
}

# Creates a new line
function newLine() {
    echo -e ""
}

# Check if the alias mka is available and falls back to something comparable.
function make_command() {
    while [[ $# -ge 1 ]]; do
        MAKE_PARAMS+="${1} "

        shift
    done

    if [[ -n $( command -v mka ) ]]; then
        mka "${MAKE_PARAMS}"
    else
        make -j"$( grep -c ^processor /proc/cpuinfo ):" "${PARAMS}"
    fi

    unset MAKE_PARAMS
}

# Parameters
while [[ $# -gt 0 ]]
do
param="$1"

case $param in
    -d|--device)
    DEVICE="$2"
    shift
    ;;
    -s|--sync)
    SYNC="sync"
    ;;
    -c|--clean)
    CLEAN="clean"
    ;;
    -l|--log)
    LOG="log"
    ;;
    -h|--help)
    echo "Usage: bash build-lineage.sh -d <device> [OPTION]

Example:
    bash build-lineage.sh -d A6020 -l -c -s

Mandatory Parameters:
    -d, --device          device you want to build for

Optional Parameters:
    -s, --sync            Repo Sync Rom before building.
    -c, --clean           clean build directory before compilation
    -l, --log             perform logging of compilation"
    exit
    ;;
esac
shift
done

if [[ -z ${DEVICE} ]]; then
    echo "You did not specify a device to build! This is mandatory parameter." && exit
fi

# Define directories
SOURCEDIR=~/los
DESTDIR=~/out/los

# SOURCEDIR is empty, prompt the user to enter it.
if [[ -z ${SOURCEDIR} ]]; then
    echo "You did not edit the SOURCEDIR variable."
    echo "Enter your Source Directory now:"
    read -r SOURCEDIR
fi

# DESTDIR is empty, prompt the user to enter it.
if [[ -z ${DESTDIR} ]]; then
    echo "You did not edit the DESTDIR variable."
    echo "Enter your Destination Directory now:"
    read -r DESTDIR
fi

# Stop the script if the user didn't fill out the above variables or refused to enter them when prompted.
if [[ -z ${SOURCEDIR} || -z ${DESTDIR} ]]; then
    echo "You did not specify a necessary variable!" && exit
fi

# Since SOURCEDIR exists now, populate these variables.
LOGDIR=$( dirname "${SOURCEDIR}" )/build-logs
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}

# custom user@host in the kernel version
export KBUILD_BUILD_USER="hsj51"
export KBUILD_BUILD_HOST="HrutvikJagtap"

##################
#                #
#  SCRIPT START  #
#                #
##################
#
# Start tracking the time to see how long it takes the script to run

echoText "SCRIPT STARTING AT $(date +%D\ %r)"
START=$(date +%s)

echoText "CURRENT DIRECTORY VARIABLES"
echo -e "Directory that contains the ROM source: ${RED}${SOURCEDIR}${RST}"
if [[ "${LOG}" == "log" ]]; then
    echo -e "Directory that contains the build logs: ${RED}${LOGDIR}${RST}"
fi
echo -e "Directory that holds the ROM zip right after compilation: ${RED}${OUTDIR}${RST}"
echo -e "Directory that holds your completed ROM zips: ${RED}${DESTDIR}${RST}"
sleep 10

# Move into the directory containing the source
echoText "MOVING INTO SOURCE DIRECTORY"
# shellcheck disable=SC2164
cd "${SOURCEDIR}"

# Sync the repo if requested
if [[ "${SYNC}" == "sync" ]]; then
    echoText "SYNCING LATEST SOURCES"
    repo sync --force-sync -j"$( grep -c ^processor /proc/cpuinfo )"
fi

# Setup the build environment
echoText "SETTING UP BUILD ENVIRONMENT"

# If the user is on arch, let's activate venv if they have it
if [[ -f /etc/arch-release ]] && [[ $( command -v virtualenv2 ) ]]; then
# shellcheck disable=SC1091
    virtualenv2 venv && source venv/bin/activate
fi

# shellcheck disable=SC1091
source build/envsetup.sh

# Prepare device
echoText "PREPARING $( echo "${DEVICE}" | awk '{print toupper($0)}' )"
lunch lineage_"${DEVICE}"-userdebug

# Clean up the out folder
echoText "CLEANING UP OUT FOLDER"
if [[ "${CLEAN}" == "clean" ]]; then
    make_command clobber
else
    make_command installclean
fi

# Log the build if requested
if [[ "${LOG}" == "log" ]]; then
    echoText "MAKING LOG DIRECTORY"
    mkdir -p "${LOGDIR}"
fi

# Start building the zip file
echoText "MAKING ZIP FILE"; newLine
NOW=$(date +"%Y-%m-%d-%S")
if [[ "${LOG}" == "log" ]]; then
    rm "${LOGDIR}"/*"${DEVICE}"*.log
    brunch "${DEVICE}" 2>&1 | tee "${LOGDIR}"/"${DEVICE}"-"${NOW}".log
else
    brunch "${DEVICE}"
fi

# If the above compilation was successful, let's notate it
FILES=$( find "${OUTDIR}"/*.zip 2>/dev/null | wc -l )
if [[ "${FILES}" != "0" ]]; then
    BUILD_RESULT_STRING="GREAT! BUILD SUCCESSFUL"

    # Push build + md5sum to remote server via SFTP

    #echoText "PUSHING FILES TO REMOTE SERVER VIA SFTP"
    #export SSHPASS=<YOUR-PASSWORD>
    #sshpass -e sftp -oBatchMode=no -b - <USER>@<HOST> << !
    #   cd <YOUR-PUBLIC-WWW-DOWNLOAD-DIRECTORY>
    #   put ${OUTDIR}/*${ZIPFORMAT}*

    # Script to remove the previous versions of the ROMs in your DESTDIR
    # (for less clutter). If the upload directory doesn't exist, make it;
    # otherwise, remove existing files in ZIPMOVE
    if [[ ! -d "${DESTDIR}" ]]; then
       newLine; echoText "MAKING DESTINATION DIRECTORY"
    # shellcheck disable=SC2115
       mkdir -p "${DESTDIR}"
    else
       newLine; echoText "CLEANING DESTINATION DIRECTORY"
    # shellcheck disable=SC2115
       rm -rf "${DESTDIR}"/*
    fi

    # Copy new files from the OUTDIR to DESTDIR (for easy of access)
    #
    # LOGIC: If there is only one zip, it means that the person is probably
    # using a build environment clsose to stock, so we'll only copy that zip file
    # Otherwise, only copy the files that don't include eng in them, since that is
    # the AOSP generated package, not the custom one we define via bacon and such
    #

    echoText "MOVING FILES"
    if [[ ${FILES} = 1 ]]; then
        mv -v "${OUTDIR}"/*.zip* "${DESTDIR}"
    else
    # shellcheck disable=SC2010
        for i in $( ls "${OUTDIR}"/*.zip* | grep -v ota ); do
            mv -v "${i}" "${DESTDIR}"
        done
    fi

# If the build failed, add a variable
else
    BUILD_RESULT_STRING="OH NO! BUILD FAILED"
fi

# Deactivate venv if applicable
if [[ -f /etc/arch-release ]] && [[ $( command -v virtualenv2 ) ]]; then
    deactivate && rm -rf "${SOURCEDIR}"/venv
fi

# Go back to the home folder
# shellcheck disable=SC2164
cd "${HOME}"

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
END=$(date +%s)
echoText "${BUILD_RESULT_STRING}!"
echo -e "${RED}" "TIME FINISHED: $( date +%D\ %r | awk '{print toupper($0)}' )"
# shellcheck disable=SC2005
echo -e "${RED}" "DURATION: $(echo "$("${END}"-"${START}")" | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" "${RST}"; newLine
