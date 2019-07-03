#!/bin/bash
#
#
# Clones everything that is needed for LineageOS-16.0
# for the Lenovo Vibe K5 (A6020)
#
# Copyright (C) hsj51 <hrutvikjagtap51@gmail.com>
# SPDX-License-Identifier: APACHE-2.0-only
#

# Prints a formatted header; used for outlining
function echoText() {
    RED="\033[01;31m"
    RST="\033[0m"

    echo -e "${RED}"
# shellcheck disable=SC2034
    echo -e "====$( for i in $(seq ${#1}); do echo -e "=\c"; done )===="
    echo -e "==  ${1}  =="
# shellcheck disable=SC2034
    echo -e "====$( for i in $(seq ${#1}); do echo -e "=\c"; done )===="
    echo -e "${RST}"
}

# Remove specific directories ( To be sure that we are using latest sources )
echoText "Removing specified directories"

rm -rf external/bson external/stlport external/sony/boringssl-compat device/qcom/common packages/resources/devicesettings

# clone all required sources (including HAls and device sources)
echoText "Cloning all sources/HALs"

git clone https://github.com/hsj51/android_device_lenovo_A6020 -b lineage-16.0 device/lenovo/A6020
git clone https://github.com/hsj51/android_vendor_lenovo_A6020 -b lineage-16.0 vendor/lenovo
git clone https://github.com/hsj51/android_kernel_lenovo_msm8916 -b lineage-16.0-rebase kernel/lenovo/msm8916

# Cloning Required Repo's
git clone https://github.com/LineageOS/android_packages_resources_devicesettings packages/resources/devicesettings
git clone https://github.com/LineageOS/android_external_bson external/bson
git clone https://github.com/LineageOS/android_external_stlport external/stlport
git clone https://github.com/LineageOS/android_external_sony_boringssl-compat external/sony/boringssl-compat
git clone https://github.com/LineageOS/android_device_qcom_common device/qcom/common




echoText "Script success!"
