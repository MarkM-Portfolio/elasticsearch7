#!/bin/bash
# A util script to migrate quickresults data from ES5 to ES7
# for additional usage, if you need to do much more complicated operation, pls
# refer to offcial site:
# https://www.elastic.co/

# the directory that all cert placed
# change this to your cert directory.
cert_dir=/opt/elasticsearch-${ES_VERSION}/config/certs
cert_dir5=/opt/elasticsearch-${ES_VERSION}/config/es5certs
URL_base="https://${ES_CLIENT_SERVICE}:9200"
URL_base5="https://${ELASTICSEARCH5_HOST}:${ELASTICSEARCH5_PORT}"

# turn off expansion to avoid asterisk becoming current directory
set -f

# please ensure those
#   cert, password, key, cacert
# are at the right location.

indices_name=$(curl \
   --insecure \
   --cert $cert_dir5/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir5/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir5/elasticsearch-http.crt.pem \
   -XGET \
   ${URL_base5}/_cat/indices/quick*?h=index -H 'Content-Type: application/json' )

echo ${indices_name}

for index_name in ${indices_name}
do
response_text=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XPOST \
   ${URL_base}/_reindex?pretty -H 'Content-Type: application/json' -d'
        {
            "source": {
                "remote": {
                "host": "'${URL_base5}'"
      
                },
            "index": "'${index_name}'"
            },
            "dest": {
                "index": "'${index_name}'",
                "version_type": "external",
                "op_type" : "index"
            },
            "conflicts" : "proceed"
        }')

# echo to return to caller.
echo ${response_text}
done
# turn expansion back to 'on'
set +f