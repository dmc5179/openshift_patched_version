#!/bin/bash

# Directory containing the release.txt files for each OCP release like:
# 4.12.12/release.txt
# 4.12.13/release.txt
#RELEASES_DIR=${RELEASES_DIR:-'/home/danclark/releases/files/mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp'}
# OpenShift 4 Version
OCP_VER=${OCP_VER:-'4.12.11'}
OCP_MAJ_VER=$(echo ${OCP_VER} | cut -d '.' -f 2)
OCP_MIN_VER=$(echo ${OCP_VER} | cut -d '.' -f 3)
# OpenShift 4 Release Image
IMAGE=${IMAGE:-'quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:0a68f56ec1f9fdc03290d420085d108fe8be13d390a4354607b79f6946cfaa2d'}
# RHSA to check patched version
RHSA=${RHSA:-'RHSA-2023:0173'}


# Name of the image in the release.txt file
IMAGE_NAME=$(curl -q "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VER}/release.txt" | grep "${IMAGE}" | awk -F\  '{print $1}')

# Check if the RHSA is actually present in the image
# TODO: Need to run on host with RHEL subscription attached to pull errata
#podman run -t --rm --user root --entrypoint '["bash", "-c", "yum list-sec"]' "${IMAGE}" > rhsas.txt
#if ! grep -q ${RHSA} rhsa.txt
#then
#  echo "RHSA not found in starting image, exiting..."
#  exit 0
#fi

echo "Scanning..."

# Get the highest possible stable version of OpenShift 4
LATEST=$(curl -q 'https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/release.txt' | grep '^Name: ' | awk -F\  '{print $NF}' | cut -d '.' -f 2)

# Highest version available in same channel as ${OCP_MAJ_VER}
# i.e start with 4.12.11 then this is highest 4.12.x release
LATEST_IN_CHANNEL_MIN=$(curl -q "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.${OCP_MAJ_VER}/release.txt" | grep '^Name: ' | awk -F\  '{print $NF}' | cut -d '.' -f 3)

# If we're already at the latest in channel then exit
#if ${OCP_MIN_VER} -eq ${LATEST_IN_CHANNEL_MIN}
#then
#  echo "Patch not found in latest version of stable ${OCP_MAJ_VER}"
#  exit 0
#fi

echo ${OCP_MIN_VER}
echo ${LATEST_IN_CHANNEL_MIN}

#for channel in $(seq $(echo "${OCP_MAJ_VER} + 1" | bc) $(echo "${LATEST} + 1" | bc)  )

for rel in $(seq $(echo "${OCP_MIN_VER} + 1" | bc) $(echo "${LATEST_IN_CHANNEL_MIN} + 1" | bc))
do
  echo "Checking release: 4.${OCP_MAJ_VER}.${rel}"

  # Get the digest of the same image name in the next release to check
  DIGEST=$(curl -q "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.${OCP_MAJ_VER}.${rel}/release.txt" | grep "${IMAGE_NAME}" | awk -F\  '{print $2}')

  echo "${DIGEST}" >> digests.txt
  continue

  # Check if the RHSA is actually present in the image
  # TODO: Need to run on host with RHEL subscription attached to pull errata
  podman run -t --rm --user root --entrypoint '["bash", "-c", "yum list-sec"]' "${DIGEST}" > "rhsas_4_${OCP_MAJ_VER}_${rel}.txt"
  if ! grep -q ${RHSA} "rhsas_4_${OCP_MAJ_VER}_${rel}.txt"
  then
    echo "RHSA not found in OCP release: 4.${OCP_MAJ_VER}.${rel}, which means the patch has been applied. Exiting"
    exit 0
  else
    echo "RHSA still present in 4.${OCP_MAJ_VER}.${rel}, checking next version"
  fi

done

# Cleanup temp files
#rm -f rhsa.txt

exit 0