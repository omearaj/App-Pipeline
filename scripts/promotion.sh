#! /bin/bash

## Shell Parameters
CF_USER=$1
CF_PASSWORD=$2
BUILD_VERSION=$3
CF_SPACE=$4
API=$5
DOMAIN=$6

## Parameters in script ##
APP_NAME=map-build-$BUILD_VERSION
#Host Name must be unique across foundation
HOST_NAME=$APP_NAME-$CF_SPACE

## Login to Cloud Foundry
cf login -a $5 -u $1 -p $2  -o WestPractice -s $4 --skip-ssl-validation

# Determine deployed APP version. Assuming 1 previously deployed version
DEPLOYED_APP_NAME=$(cf apps | grep 'map-build-' | cut -d" " -f1)

# CF CLI commands
cf push $APP_NAME -n $HOST_NAME -m 1GB -p target/pcfdemo.war -t 180 -i 2 --no-start
cf map-route $APP_NAME $6 -n maps
cf bind-service $APP_NAME myRabbit
cf start $APP_NAME

#Perform Blue Green deployment
if [ ! -z "$DEPLOYED_APP_NAME" -a "$DEPLOYED_APP_NAME" != " " -a "$DEPLOYED_APP_NAME" != "$APP_NAME" ]; then
  echo "Performing zero-downtime cutover to $BUILD_VERSION"
  #while read line
  #do
   # if [ ! -z "$line" -a "$line" != " " -a "$line" != "$APP_NAME" ]; then
      #echo "Scaling down, unmapping and removing $line"
      #cf scale "$line" -i 1
      cf scale "$DEPLOYED_APP_NAME" -i 1
      cf unmap-route "$DEPLOYED_APP_NAME" $6 -n maps
      # cf unmap-route "$line" cfapps.io -n cities-uniquetoken
      cf delete "$DEPLOYED_APP_NAME" -f -r
    #else
    #  echo "Skipping $line"
   # fi
  # done <<< "$DEPLOYED_VERSION"
fi

cf lo
