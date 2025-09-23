WORKING_DIR=.
ELASTICSEARCH_DIR=${WORKING_DIR}/ElasticSearch
cd ${ELASTICSEARCH_DIR}
set -e
rm -rf ca/
rm -rf certs/
rm -rf crl/
rm -f ./*tmp*
rm -f *.txt
rm -f ./elasticsearch*
cd ${WORKING_DIR}
