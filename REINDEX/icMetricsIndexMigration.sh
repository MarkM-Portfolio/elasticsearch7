#!/bin/bash
# A util script to migrate metrics index from ES5 to ES7
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
indexlist="icidmap icmetricsconfig icmetricsreport icmetricscommlist"

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
   ${URL_base5}/_cat/indices/ic*?h=index -H 'Content-Type: application/json' )

echo ${indices_name}

for index_name in ${indices_name}
do
  index_settings=$(curl \
   --insecure \
   --cert $cert_dir5/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir5/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir5/elasticsearch-http.crt.pem \
   -XGET \
   ${URL_base5}/${index_name}/_settings/index.number_of_shards,index.number_of_replicas -H 'Content-Type: application/json' )

index_settings=$(grep -o '"settings":{"index":{"number_of_shards":".*","number_of_replicas":".*"}}' <<< "${index_settings}")
response_text=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XPUT \
   ${URL_base}/${index_name} -H 'Content-Type: application/json' -d '
   {
   '${index_settings}'
   }')
echo ${index_settings}
echo ${response_text}

if [[ ${indexlist} == *"${index_name}"* ]]
then
response_text=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XPUT \
   ${URL_base}/${index_name}/_mappings -H 'Content-Type: application/json' --data-binary @${mappings_dir}/k8.${index_name}7.mapping.json)
echo ${response_text}
else
response_text=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XPUT \
   ${URL_base}/${index_name}/_mappings -H 'Content-Type: application/json' --data-binary @${mappings_dir}/k8.icevent7.mapping.json)
echo ${response_text}
fi
done

aliases=$(curl \
   --insecure \
   --cert $cert_dir5/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir5/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir5/elasticsearch-http.crt.pem \
   -XGET \
   "${URL_base5}/_cat/aliases/ic*?h=alias" -H 'Content-Type: application/json' )
   
echo ${aliases}

for alias in ${aliases}
do
  aliasindex=$(curl \
   --insecure \
   --cert $cert_dir5/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir5/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir5/elasticsearch-http.crt.pem \
   -XGET \
   "${URL_base5}/_cat/aliases/${alias}?h=index" -H 'Content-Type: application/json' )
   
echo ${aliasindex}

for index in ${aliasindex}
do   
   aliasadded=$(curl \
   --insecure \
   --cert $cert_dir/elasticsearch-healthcheck.crt.pem:${KEY_PASS} \
   --key  $cert_dir/elasticsearch-healthcheck.des3.key \
   --cacert $cert_dir/elasticsearch-http.crt.pem \
   -XPOST \
   "${URL_base}/_aliases" -H 'Content-Type: application/json' -d '
{
  "actions" : [
    { "add" : { "index" : "'${index}'", "alias" : "'${alias}'" } }
  ]
}
')
echo ${aliasadded}
done
done

# turn expansion back to 'on'
set +f