#!/bin/bash
#
# See https://cloud.google.com/cloud-build/docs/build-debug-locally
#

set -e

config=$(mktemp)
cp releasing/cloudbuild.yaml $config

# Very important - cloudbuild.yaml won't work unless
# this is defined.
export TAG_NAME=$1

# Delete the cloud-builders/git step, which isn't needed
# for a local run.
sed -i '2,3d' $config

# Add the --snapshot flag to suppress the
# github release and leave the build output
# in the kustomize/dist directory.
sed -i 's|"\]$|", "--snapshot"]|' $config

echo "Executing cloud-build-local with:"
echo "========================="
cat $config
echo "========================="

cloud-build-local \
    --config=$config \
    --bind-mount-source \
    --dryrun=false \
    .

echo " "
echo "Result of local build:"
echo "##########################################"
tree ./$module/dist
echo "##########################################"
