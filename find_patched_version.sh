#!/bin/bash -e

# Parameters
# OCP_VER = OpenShift version, i.e; 4.12.11
# IMAGE = Digest of OpenShift image the RHSA is found in, i.e; quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:0a68f56ec1f9fdc03290d420085d108fe8be13d390a4354607b79f6946cfaa2d
# RHSA = RHSA to scan for, i.e; RHSA-2023:0173

# OpenShift 4 Version
OCP_VER=${OCP_VER:-'4.12.11'}
OCP_MAJ_VER=$(echo ${OCP_VER} | cut -d '.' -f 2)
OCP_MIN_VER=$(echo ${OCP_VER} | cut -d '.' -f 3)
# OpenShift 4 Release Image
IMAGE=${IMAGE:-'quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:0a68f56ec1f9fdc03290d420085d108fe8be13d390a4354607b79f6946cfaa2d'}
# RHSA to check patched version
RHSA=${RHSA:-'RHSA-2023:0173'}


# Name of the image in the release.txt file
IMAGE_NAME=$(curl -s "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VER}/release.txt" | grep "${IMAGE}" | awk -F\  '{print $1}')

# Check if the RHSA is actually present in the image
# TODO: Need to run on host with RHEL subscription attached to pull errata
#podman run -t --rm --user root --entrypoint '["bash", "-c", "yum list-sec"]' "${IMAGE}" > rhsas.txt
#if ! grep -q ${RHSA} rhsa.txt
#then
#  echo "RHSA not found in starting image, exiting..."
#  exit 0
#fi

if [ ! -d rhsas ]
then
  mkdir rhsas
fi

echo "Scanning..."

# Get the highest possible stable version of OpenShift 4
LATEST=$(curl -s 'https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/release.txt' | grep '^Name: ' | awk -F\  '{print $NF}' | cut -d '.' -f 2)

while [ ${OCP_MAJ_VER} -le ${LATEST} ]
do

  # Highest version available in same channel as ${OCP_MAJ_VER}
  # i.e start with 4.12.11 then this is highest 4.12.x release
  LATEST_IN_CHANNEL_MIN=$(curl -s "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.${OCP_MAJ_VER}/release.txt" | grep '^Name: ' | awk -F\  '{print $NF}' | cut -d '.' -f 3)
  
  echo ${OCP_MIN_VER}
  echo ${LATEST_IN_CHANNEL_MIN}
  echo ${LATEST}
  
  for rel in $(seq $(echo "${OCP_MIN_VER} + 1" | bc) ${LATEST_IN_CHANNEL_MIN})
  do
    echo "Checking release: 4.${OCP_MAJ_VER}.${rel}"
  
    # Get the digest of the same image name in the next release to check
    DIGEST=$(curl -s "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.${OCP_MAJ_VER}.${rel}/release.txt" | grep "${IMAGE_NAME}" | awk -F\  '{print $2}')
  
    #echo "${DIGEST}" >> digests.txt
    #continue
  
    # Check if the RHSA is actually present in the image
    # TODO: Need to run on host with RHEL subscription attached to pull errata
    # Only run this command if I don't already have the list from this image
    if [ ! -e "rhsas/${IMAGE_NAME}_rhsas_4_${OCP_MAJ_VER}_${rel}.txt" ]
    then
      podman run -t --rm --user root --entrypoint '["bash", "-c", "yum list-sec"]' "${DIGEST}" > "rhsas/${IMAGE_NAME}_rhsas_4_${OCP_MAJ_VER}_${rel}.txt"
    fi

    #TODO: Check that the file is non-zero
    if ! grep -q ${RHSA} "rhsas/${IMAGE_NAME}_rhsas_4_${OCP_MAJ_VER}_${rel}.txt"
    then
      echo "RHSA not found in OCP release: 4.${OCP_MAJ_VER}.${rel}, which means the patch has been applied. Exiting"
      exit 0
    else
      echo "RHSA still present in 4.${OCP_MAJ_VER}.${rel}, checking next version"
    fi
  
  done

  OCP_MIN_VER=0
  let "OCP_MAJ_VER++"

done

# Cleanup temp files
#rm -f rhsa.txt

exit 0
