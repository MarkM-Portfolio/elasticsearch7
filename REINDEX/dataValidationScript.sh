#!/bin/bash
# A util script to migrate quickresults index from ES5 to ES7
# for additional usage, if you need to do much more complicated operation, pls
# refer to offcial site:
# https://www.elastic.co/

# the directory that all cert placed
# change this to your cert directory.
cert_dir=/opt/elasticsearch-${ES_VERSION}/config/certs
cert_dir5=/opt/elasticsearch-${ES_VERSION}/config/es5certs
URL_base="https://${ES_CLIENT_SERVICE}:9200"
URL_base5="https://${ELASTICSEARCH5_HOST}:${ELASTICSEARCH5_PORT}"
mappings_dir=/opt/elasticsearch-${ES_VERSION}/config/mappings

# turn off expansion to avoid asterisk becoming current directory
set -f

# please ensure those
#   cert, password, key, cacert
# are at the right location.
if [ "${1:-}" = "" ]; then
echo "Please enter index name as an arguement"
else
index_name=$1
 
echo ${index_name}

es5count=$(curl \
   --insecure \
   --cert $cert_dir5/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir5/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir5/elasticsearch-http.crt.pem \
   -XGET \
   ${URL_base5}/${index_name}/_count -H 'Content-Type: application/json' )
es5count=$(grep -o '"count":[[:digit:]]*' <<< "${es5count}")

if [[ ${es5count} == "" ]]
then
echo "Index does not exist in elasticsearch5"
else

echo "Data in ES5 pods '${es5count}' for '${index_name}'"

es7count=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XGET \
   ${URL_base}/${index_name}/_count -H 'Content-Type: application/json' )
es7count=$(grep -o '"count":[[:digit:]]*' <<< "${es7count}")
echo "Data in ES7 pods '${es7count}' for '${index_name}'"
if [[ ${es5count} == ${es7count} ]]
then
echo "Documents count for index '${index_name}' is same in elasticsearch5 and elasticsearch7"
else
echo "Data Mismatch, please run Data Migration Script again as per requirement."
fi
fi
fi
# turn expansion back to 'on'
set +f