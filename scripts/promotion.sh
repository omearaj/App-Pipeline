#! /bin/bash

## This script is used to test the BASH script components
## of a Jenkins Job using the Cloud Foundry CLI.
## This portion of the script is usually a
## downstream job for continuous delivery.

## Parameters used to test the BASH script
## They will be provided by Jenkins plugins,
## Jenkins environment variables or job parameters
CF_USER=$1
CF_PASSWORD=$2
CF_ORG=$3
CF_SPACE=$4
API=$5
DOMAIN=$6
BUILD_VERSION=$7

## Variables used during Jenkins Build Process
APP_NAME=map-build-$BUILD_VERSION
#Host Name must be unique across foundation
HOST_NAME=$APP_NAME-$CF_SPACE

## Login to Cloud Foundry usually performed by Jenkins Plugin
cf login -u $CF_USER -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE -a $API --skip-ssl-validation

## These steps complete the following, they are the only required steps for the Jenkins Job
##
##   1. Determine the name of the deployed app. The naming convention for this
##      app is map-build-BUILD_NUMBER, ex map-build-45. We assume only 1 previous build
##      exist.
##
##   2. Push the promoted app to production and bind it to the required services, like Rabbit.
##      Map the external route name, maps in this case, to the production app
##
##   3. Scale down the existing version, unmap the external route and delete it.
##
##   Note: Best practice is to keep the previous version in case of roll back.
##
##   4. Log out
##

DEPLOYED_APP_NAME=$(cf apps | grep 'map-build-' | cut -d" " -f1)

cf push $APP_NAME -n $HOST_NAME -m 1GB -p artifacts/pcfdemo.war -t 180 -i 2 --no-start
cf bind-service $APP_NAME myRabbit
cf start $APP_NAME
cf map-route $APP_NAME $DOMAIN -n maps

#Perform Blue Green deployment
if [ ! -z "$DEPLOYED_APP_NAME" -a "$DEPLOYED_APP_NAME" != " " -a "$DEPLOYED_APP_NAME" != "$APP_NAME" ]; then
  echo "Performing zero-downtime cutover to $BUILD_VERSION"
  cf scale "$DEPLOYED_APP_NAME" -i 1
  cf unmap-route "$DEPLOYED_APP_NAME" $DOMAIN -n maps
  cf delete "$DEPLOYED_APP_NAME" -f -r
fi

cf lo
