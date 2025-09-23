#bin/bash

# Function to create Root CA for ElasticSearch cluster
function createESRootCA {
	set -o errexit
	set -o pipefail
	set -o nounset
	# Create Root CA for ElasticSearch cluster
	mkdir -p ca/root-ca/private ca/root-ca/db crl certs
	chmod 700 ca/root-ca/private

	cp /dev/null ca/root-ca/db/root-ca.db
	cp /dev/null ca/root-ca/db/root-ca.db.attr
	echo 01 > ca/root-ca/db/root-ca.crt.srl
	echo 01 > ca/root-ca/db/root-ca.crl.srl

	openssl req -new \
		-config caconfig/root-ca.conf \
		-out ca/root-ca.csr \
		-keyout ca/root-ca/private/root-ca.key \
		-batch \
		-passout pass:$set_elasticsearch_ca_password

	openssl ca -selfsign \
		-config caconfig/root-ca.conf \
		-in ca/root-ca.csr \
		-out ca/root-ca.crt \
		-extensions root_ca_ext \
		-batch \
		-passin pass:$set_elasticsearch_ca_password

	echo Root CA generated

	# Create Signing CA for ElasticSearch cluster
	mkdir -p ca/signing-ca/private ca/signing-ca/db crl certs
	chmod 700 ca/signing-ca/private

	cp /dev/null ca/signing-ca/db/signing-ca.db
	cp /dev/null ca/signing-ca/db/signing-ca.db.attr
	echo 01 > ca/signing-ca/db/signing-ca.crt.srl
	echo 01 > ca/signing-ca/db/signing-ca.crl.srl

	openssl req -new \
		-config caconfig/signing-ca.conf \
		-out ca/signing-ca.csr \
		-keyout ca/signing-ca/private/signing-ca.key \
		-batch \
		-passout pass:$set_elasticsearch_ca_password

	openssl ca \
		-config caconfig/root-ca.conf \
		-in ca/signing-ca.csr \
		-out ca/signing-ca.crt \
		-extensions signing_ca_ext \
		-batch \
		-passin pass:$set_elasticsearch_ca_password

	echo Signing CA generated

	#Covert crt files to PEM format
	openssl x509 -in ca/root-ca.crt -out ca/root-ca.pem -outform PEM
	openssl x509 -in ca/signing-ca.crt -out ca/signing-ca.pem -outform PEM
	cat ca/signing-ca.pem ca/root-ca.pem > ca/chain-ca.pem
}

# Function to create Server Certificate for each of ElasticSearch Node
function createESNodeCert {
	set -o errexit
	set -o pipefail
	set -o nounset

	NODE_NAME=elasticsearch-$1
	SERVER_NAME=/CN=${NODE_NAME}/OU=CES/O=HCL/C=US
	openssl genrsa -out $NODE_NAME.key.tmp 2048
	openssl pkcs8 -v1 "PBE-SHA1-3DES" -topk8 -inform pem -in $NODE_NAME.key.tmp -outform pem -out $NODE_NAME.key -passout "pass:$set_elasticsearch_key_password"

	openssl req -new -key $NODE_NAME.key -out $NODE_NAME.csr -passin "pass:$set_elasticsearch_key_password" \
	   -subj "$SERVER_NAME" \
	   -reqexts v3_req \
		 -config caconfig/node-ssl.conf

	openssl ca \
		-in "$NODE_NAME.csr" \
		-notext \
		-out "$NODE_NAME-signed.pem" \
		-config caconfig/signing-ca.conf \
		-extensions v3_req \
		-batch \
		-passin "pass:$set_elasticsearch_ca_password" \
		-days 730 \
		-extensions server_ext

	#we do not add the root certificate to the chain
	cat "$NODE_NAME-signed.pem" ca/signing-ca.pem  > $NODE_NAME.crt.pem
	openssl pkcs12 -export -in "$NODE_NAME.crt.pem" -inkey "$NODE_NAME.key" -out "$NODE_NAME.p12" -passin "pass:$set_elasticsearch_key_password" -passout "pass:$set_elasticsearch_key_password"
}

# Function to create Clinet Certificate for client of ElasticSearch Cluster
function createESClientCert {
	set -o errexit
	set -o pipefail
	set -o nounset

	CLIENT_NAME=elasticsearch-$1
	SERVER_NAME=/CN=${CLIENT_NAME}/OU=CES/O=HCL/C=US
	openssl genrsa -out $CLIENT_NAME.key.tmp 2048
	openssl pkcs8 -v1 "PBE-SHA1-3DES" -topk8 -inform pem -in $CLIENT_NAME.key.tmp -outform pem -out $CLIENT_NAME.key -passout "pass:$set_elasticsearch_key_password"

	#Curl7.29 only works with des encrytped key, so we also need the des ecnrytped version of private key
	openssl rsa -des3 -in $CLIENT_NAME.key.tmp -out $CLIENT_NAME.des3.key -passout "pass:$set_elasticsearch_key_password"

	openssl req -new -key $CLIENT_NAME.key -out $CLIENT_NAME.csr -passin "pass:$set_elasticsearch_key_password" \
		-subj "$SERVER_NAME" \
		-reqexts v3_req \
		-config caconfig/client-ssl.conf

	openssl ca \
		-in "$CLIENT_NAME.csr" \
		-notext \
		-out "$CLIENT_NAME-signed.pem" \
		-config caconfig/signing-ca.conf \
		-extensions v3_req \
		-batch \
		-passin "pass:$set_elasticsearch_ca_password" \
		-days 730 \
		-extensions server_ext

	#we do not add the root certificate to the chain
	cat "$CLIENT_NAME-signed.pem" ca/signing-ca.pem  > $CLIENT_NAME.crt.pem
	openssl pkcs12 -export -in "$CLIENT_NAME.crt.pem" -inkey "$CLIENT_NAME.key" -out "$CLIENT_NAME.p12" -passin "pass:$set_elasticsearch_key_password" -passout "pass:$set_elasticsearch_key_password"
}

# function to clean all the certificates and CAs
function cleanESCerts {
	set -o errexit
	rm -rf ca/
	rm -rf certs/
	rm -rf crl/
	rm -f ./*tmp*
	rm -f *.txt
	rm -f ./elasticsearch*
}

# return is in set_secret
# function resets errexit to ignore so calling script must reset if desired
function readPassword() {
	set +o errexit
	set -o pipefail
	set +o nounset

	if [ "$1" = "" ]; then
		echo "usage:  readPassword sDescriptor"
		exit 107
	fi
	set -o nounset
	descriptor="$1"
	set_secret=""

	echo
	while [ "${set_secret}" = "" ]; do
		echo
		printf "${descriptor}: "
		read -s set_secret		# -s not working #2770
		printf "\n${descriptor} (confirmation):  "
		read -s set_secret_confirm	# -s not working #2770
		if [ "${set_secret}" != "${set_secret_confirm}" ]; then
			echo
			echo "=== Input does not match, try again"
			set_secret=""
			continue
		fi
	done
}

# function to read all the password needed by creating elasticsearch secrets
function readESPasswords {
	set -o errexit
	set -o pipefail
	set -o nounset

	if [ -z "${set_elasticsearch_ca_password}" ]; then
		readPassword "ElasticSearch CA password"
		set_elasticsearch_ca_password=${set_secret}
	fi

	if [ -z "${set_elasticsearch_key_password}" ]; then
		readPassword "ElasticSearch password to protect the server private key"
		set_elasticsearch_key_password=${set_secret}
  fi
}

# funtion to write elaticsearch secrets to k8s secret 'elasticsearch-secret'
function writeESSecrets {
	set -o errexit
	set -o pipefail
	set -o nounset

	elasticsearch_cert_files=(
		"elasticsearch-ca-password.txt"
		"elasticsearch-key-password.txt"
		"elasticsearch-transport.key"
		"elasticsearch-http.key"
		"elasticsearch-transport.crt.pem"
		"elasticsearch-http.crt.pem"
		"elasticsearch-admin.key"
		"elasticsearch-admin.crt.pem"
		"elasticsearch-metrics.key"
		"elasticsearch-metrics.crt.pem"
		"elasticsearch-orientme.key"
		"elasticsearch-orientme.crt.pem"
		"elasticsearch-peoplesearch.key"
		"elasticsearch-peoplesearch.crt.pem"
		"elasticsearch-contentsearch.key"
		"elasticsearch-contentsearch.crt.pem"
		"elasticsearch-healthcheck.key"
		"elasticsearch-healthcheck.des3.key"
		"elasticsearch-healthcheck.crt.pem"
		"ca/chain-ca.pem"
	)

	elasticsearch_secret_cmd="kubectl create secret generic elasticsearch-7-secret -n="${NAMESPACE}""
	for elasticsearch_cert_file in "${elasticsearch_cert_files[@]}"
	do
		elasticsearch_secret_cmd="$elasticsearch_secret_cmd --from-file=$elasticsearch_cert_file"
	done

	eval $elasticsearch_secret_cmd

	#Export elasticsearch-secret in order to have a safely backup
	kubectl get secret elasticsearch-7-secret -o yaml -n="${NAMESPACE}" > elasticsearch-7-secret.yaml
}

WORKING_DIR=$(cd `dirname $0`; pwd)
echo ${WORKING_DIR}
ELASTICSEARCH_DIR=${WORKING_DIR}/elasticsearch
NAMESPACE="connections"
set_elasticsearch_ca_password=""
set_elasticsearch_key_password=""

for arg in $*; do
		 echo ${arg} | grep -q -e --set_elasticsearch_ca_password=
			if [ $? -eq 0 ]; then
				set_elasticsearch_ca_password=`echo ${arg} | awk -F= '{ print $2 }'`
			fi
			echo ${arg} | grep -q -e --set_elasticsearch_key_password=
			if [ $? -eq 0 ]; then
				set_elasticsearch_key_password=`echo ${arg} | awk -F= '{ print $2 }'`
			fi
done

if [ -z "${set_elasticsearch_ca_password}" ] || [ -z "${set_elasticsearch_key_password}" ]; then
	readESPasswords
fi

if [ -n "${set_elasticsearch_ca_password}" ] && [ -n "${set_elasticsearch_key_password}" ]; then
	cd ${ELASTICSEARCH_DIR}
	cleanESCerts

	echo ${set_elasticsearch_ca_password} > elasticsearch-ca-password.txt
	echo ${set_elasticsearch_key_password} > elasticsearch-key-password.txt

	createESRootCA
	createESNodeCert 'http' && createESNodeCert 'transport'
	createESClientCert 'admin' && createESClientCert 'metrics' && createESClientCert 'peoplesearch' && createESClientCert 'healthcheck' && createESClientCert 'contentsearch' && createESClientCert 'orientme'

	#delete secret if exists
	kubectl delete --ignore-not-found secret elasticsearch-7-secret -n ${NAMESPACE}
	writeESSecrets
	cd ${WORKING_DIR}
fi
