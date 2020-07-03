#!/bin/bash
set -e
set -x

# Script to run http://goreleaser.com

# Removed from `build` stanza
# binary: $module

module=$1
shift

function setSemVer {
  # Check the tag for consistency with module name.
  # The following assumes git tags formatted like
  # "api/v1.2.3" and splits on the slash.
  # Goreleaser doesn't know what to do with this
  # tag format, and fails when creating an archive
  # with a / in the name.
  local fullTag=$(git describe)
  local tModule=${fullTag%/*}
  semVer=${fullTag#*/}

  # Make sure version has no slash
  # (k8s/v0.1.0 becomes v0.1.0)
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

configFile=$(mktemp)
cat <<EOF >$configFile
project_name: $module
env:
- CGO_ENABLED=0
- GO111MODULE=on
checksum:
  name_template: 'checksums.txt'
changelog:
  sort: asc
  filters:
    exclude:
    - '^docs:'
    - '^test:'
    - Merge pull request
    - Merge branch
release:
  github:
    owner: kubernetes-sigs
    name: kustomize
  draft: true
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
archives:
-  name_template: "${module}_${semVer}_{{ .Os }}_{{ .Arch }}"
EOF

cat $configFile

/bin/goreleaser release --config=$configFile --rm-dist --skip-validate $@
