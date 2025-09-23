#!/bin/bash
set -ex

ARTIFACTORY_HOST_IP=$(dig +short artifactory.cwp.pnp-hcl.com)
DOCKER_TIMESTAMP=$(date +"%Y%m%d-%H%M")

IMAGE_NAME=elasticsearch-cluster
ES_VERSION=$(cat es_version)
DOCKER_IMAGE_TAG=connections-docker.artifactory.cwp.pnp-hcl.com/$IMAGE_NAME:$ES_VERSION-$DOCKER_TIMESTAMP
DOCKER_TESTED_IMAGE_TAG=connections-docker.artifactory.cwp.pnp-hcl.com/$IMAGE_NAME:latest

APP_IMAGE_ID=$(docker build -q --no-cache --build-arg ARTIFACTORY_HOST_IP=$ARTIFACTORY_HOST_IP \
            --build-arg ARTIFACTORY_USER=$gitbuild_user_name \
            --build-arg ARTIFACTORY_PASS=$gitbuild_user_password \
            --build-arg BUILD_TIMESTAMP=$DOCKER_TIMESTAMP \
	    -t $DOCKER_IMAGE_TAG \
-t $DOCKER_TESTED_IMAGE_TAG .)

docker push $DOCKER_IMAGE_TAG
docker push $DOCKER_TESTED_IMAGE_TAG
docker rmi -f $APP_IMAGE_ID
