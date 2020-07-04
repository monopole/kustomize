#!/bin/bash
#
# Usage (from top of repo):
#
#  releasing/cloudbuild.sh TAG [--snapshot]
#
# Where TAG is in the form
#
#   api/v1.2.3
#   kustomize/v1.2.3
#   cmd/config/v1.2.3
#   ... etc.
#
# Cloud build should be configured to trigger on tags
# matching:
#
#   [\w/]+/v\d+\.\d+\.\d+
#
# This script runs goreleaser (http://goreleaser.com),
# so the google cloud config should install the image,
# the run this.

set -e
set -x

fullTag=$1
shift
echo "fullTag=$fullTag"

remainingArgs="$@"
echo "Remaining args:  $remainingArgs"

# Take everything before the last slash.
# This is expected to match $module.
module=${fullTag%/*}
echo "module=$module"

# Take everything after the last slash.
# This should be something like "v1.2.3".
semVer=`echo $fullTag | sed "s|$module/||"`
echo "semVer=$semVer"

# This is probably a directory called /workspace
pwd

# These files should look like the top of the repository
echo "### ls -las . ################################"
ls -las .
echo "## ls / #################################"
ls /
echo "### ls /bin ################################"
ls /bin
echo "### ls /usr/bin ################################"
ls /usr/bin
echo "###################################"


# CD into the module directory.
# This directory expected to contain a main.go, so there's
# no need for extra details in the `build` stanza below.
cd $module

# 2020/May/11 Windows build temporaraily removed
# ("- windows" removed from the goos: list below)
# because of https://github.com/microsoft/go-winio/issues/161
# Seeing the following in builds:
#   : /go/pkg/mod/golang.org/x/crypto@v0.0.0-20190923035154-9ee001bba392/ssh/terminal/util_windows.go:97:61:
#  multiple-value "golang.org/x/sys/windows".GetCurrentProcess() in single-value context

configFile=$(mktemp)
cat <<EOF >$configFile
project_name: $module

archives:
- name_template: "${module}_${semVer}_{{ .Os }}_{{ .Arch }}"

builds:
- ldflags: >
    -s
    -X sigs.k8s.io/kustomize/api/provenance.version={{.Version}}
    -X sigs.k8s.io/kustomize/api/provenance.gitCommit={{.Commit}}
    -X sigs.k8s.io/kustomize/api/provenance.buildDate={{.Date}}

  goos:
  - linux
  - darwin
  - windows

  goarch:
  - amd64

changelog:
  sort: asc
  filters:
    exclude:
    - '^docs:'
    - '^test:'
    - Merge pull request
    - Merge branch

checksum:
  name_template: 'checksums.txt'

env:
- CGO_ENABLED=0
- GO111MODULE=on

release:
  github:
    owner: monopole
    name: kustomize
  draft: true

EOF

cat $configFile

/bin/goreleaser release --config=$configFile --rm-dist --skip-validate $remainingArgs
