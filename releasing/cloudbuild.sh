#!/bin/bash
set -e
set -x

# Shell script to run http://goreleaser.com
# First it dynamically creates the goreleaser input file,
# then it runs goreleaser.

# This is one of kustomize, api, kyaml, etc.
module=$1
shift


which git

git version

# For logging and debugging.
git status

# For logging and debugging.
# This shows most recent tag, which is presumably
# the tag we're releasing.  If not, there might
# be a problem.
git describe


# Check the tag for consistency with the given module name.
# The following assumes git tags formatted like
# "api/v1.2.3" or "cmd/config/v1.2.3" and splits on the last
# slash.
#
# Goreleaser doesn't know what to do the first part of this
# tag format, and fails when creating an archive
# with a / in the name.
function setSemVer {
  local fullTag=$(git describe)
  local tModule=${fullTag%/*}
  semVer=${fullTag#*/}

  # Make sure version has no slash
  # (foo/v0.1.0 becomes v0.1.0)
  local tmp=${semVer#*/}
  if [ "$tmp" != "$semVer" ]; then
    semVer="$tmp"
  fi

  echo "tModule=$tModule"
  echo "semVer=$semVer"
  if [ "$module" != "$tModule" ]; then
    # Tag and argument sanity check
    echo "Unexpected mismatch: moduleFromArg=$module, moduleFromTag=$tModule"
    echo "Either the module arg to this script is wrong, or the git tag is wrong."
    # exit 1
  fi
}

setSemVer

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

/bin/goreleaser release --config=$configFile --rm-dist --skip-validate $@
