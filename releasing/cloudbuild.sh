#!/bin/bash
set -e
set -x

# Shell script to run http://goreleaser.com
# First it dynamically creates the goreleaser input file,
# then it runs goreleaser.

# This is one of kustomize, api, kyaml, cmd/config, etc.
# It's provided by a Google cloudbuild.yaml file.
module=$1
shift
echo "module=$module"

# This should be the value of the tag that triggered the build.
# It's provided by a Google cloudbuild.yaml file.
fullTag=$1
shift
echo "fullTag=$fullTag"

remainingArgs="$@"
echo "Remaining args:  $remainingArgs"

# Take everything before the last slash.
# This is expected to match $module.
tModule=${fullTag%/*}
echo "tModule=$tModule"

if [ "$module" != "$tModule" ]; then
  # Tag and argument sanity check
  echo "Unexpected mismatch: module from arg = '$module', module from tag = '$tModule"
  echo "Either the module arg to this script is wrong, or the git tag is wrong."
  # exit 1
fi

# Take everything after the last slash.
# This should be something like "v1.2.3".
semVer=`echo $fullTag | sed "s|$tModule/||"`
echo "semVer=$semVer"

pwd
ls

if [ "$module" == "jeff" ]; then
  module=api
fi

# CD into the module directory.
# Since that's where the main.go is, there's no need for
# the `main`less is needed
# in the `build` stanza below.
cd $module

# 2020/May/11 Windows build temporaraily removed
# ("- windows" removed from the goos: list below)
# because of https://github.com/microsoft/go-winio/issues/161
# Seeing the following in builds:
#   : /go/pkg/mod/golang.org/x/crypto@v0.0.0-20190923035154-9ee001bba392/ssh/terminal/util_windows.go:97:61:
#  multiple-value "golang.org/x/sys/windows".GetCurrentProcess() in single-value context

echo "_GITHUB_USER=$_GITHUB_USER"
echo "_PR_NUMBER=$_PR_NUMBER"
echo "REPO_NAME=$REPO_NAME"
echo "HEAD_REPO_URL=$_HEAD_REPO_URL"
echo "TAG_NAME=$TAG_NAME"

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

echo "## ls / #################################"
ls /
echo "### ls /bin ################################"
ls /bin
echo "### ls . ################################"
ls .
echo "###################################"

/bin/goreleaser release --config=$configFile --rm-dist --skip-validate $remainingArgs
