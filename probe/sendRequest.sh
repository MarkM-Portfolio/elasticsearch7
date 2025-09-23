#!/bin/bash
# An util script so that you can interact with es like what official site suggested:
# for usage, please refer to
# ./doBackup.sh
# ./doRestore.sh
# ./master-readiness.sh
# for additional usage, if you need to do much more complicated operation, pls
# refer to offcial site:
# https://www.elastic.co/


set -o errexit
set -o pipefail
set -o nounset

# the directory that all cert placed
# change this to your cert directory.
cert_dir=/opt/elasticsearch-${ES_VERSION}/config/certs
PARAM_TO_MASTER="--to-master"

# deal with param --to-master
if [ "${1:-}" = "${PARAM_TO_MASTER}" ]; then
  shift 1
  URL_base="https://${ES_DISCOVERY_SERVICE}:9200"
else
  URL_base="https://${ES_CLIENT_SERVICE}:9200"
fi

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage: sendRequest.sh [${PARAM_TO_MASTER}]  param_method param_url [additional param]"
  echo "Request is send to es client(coordinating node) by default. add param"
  echo "  ${PARAM_TO_MASTER}"
  echo "to send request to es master node"
  echo "refer: https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html"
  exit 107
fi

# save the HTTPS METHOD.
_method=$1
# and then shfit this argument.
# since we need to pass the rest args to curl command unchanged.
shift 1

# turn off expansion to avoid asterisk becoming current directory
set -f

# please ensure those
#   cert, password, key, cacert
# are at the right location.
response_text=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -X${_method} \
   ${URL_base}"$@")

# echo to return to caller.
echo ${response_text}
# turn expansion back to 'on'
set +f
