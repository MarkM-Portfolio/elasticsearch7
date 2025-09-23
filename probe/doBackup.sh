#!/bin/bash
# for additional usage, pls refer to official site:
# https://www.elastic.co/guide/en/elasticsearch/guide/current/backing-up-your-cluster.html
# PS: with probe/sendRequest.sh, you can interact with es like what official site suggested.

set -o errexit
set -o pipefail
set -o nounset

# this path of util script sendRequest.sh.
# pls change it to the path in your env. e.g:
#   /opt/elasticsearch-7.10.1/probe/sendRequest.sh
sendRequest="/opt/elasticsearch-${ES_VERSION}/probe/sendRequest.sh"

if [ "${1:-}" = "" ]; then
  echo "usage:  doBackup.sh param_REPO_name"
  exit 107
fi

# Name of our snapshot repository
# pls change this to the repo that need to do backup.
REPO=${1}

echo "----------------to create a snapshot ${REPO}"
# 1. Currently, we use snapshot$(date +%Y%m%d%H%M%S) as the name of snapshot.
# change it if you need a customized one.
# 2. With
#   wait_for_completion=true
# this command with end when backup finished, and the backup result will be printed
# to check if this backup operation succeed.
${sendRequest} PUT /_snapshot/${REPO}/snapshot$(date +%Y%m%d%H%M%S)?wait_for_completion=true

# echo "----------------to check all exists snapshot"
# ${sendRequest}/sendRequest.sh get /_snapshot/${REPO}/_all?pretty

# to delete a snapshot
# ${sendRequest}/sendRequest.sh DELETE /_snapshot/${REPO}/${SNAPSHOT}?pretty

exit 0
