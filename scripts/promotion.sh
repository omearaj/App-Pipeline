#! /bin/bash
set -e

## This script is used to test the BASH script commands
## of a Jenkins Job using the Cloud Foundry CLI.
## This script is based on previous version written by Matt Stine and Jamie O'Meara
## Author - Sufyaan Kazi - Pivotal

usage ()
{
  echo 'Usage : Script -u <user> -pw <password> -o <org> -s <space>'
  echo '               -d <domain> -ap <app_prefix> -v <build_version>'
  echo '               -sn <serviceName> -m <memory> -p <path_to_app> -i <instances>'
  echo ' e.g. ./deployment.sh -u suf -pw ******** -o suf-org -s dev -d emea.fe.pivotal.io -ap cities-ui -sn citiesService -m 512m -p artifacts/cities-ui.jar i 1 -v 9'
  exit
}

if [ "$#" -eq 0 ]
then
  usage
fi

## Parameters used to test the BASH script
## They will be provided by Jenkins plugins,
## Jenkins environment variables or job parameters
while [ "$1" != "" ]; do
case $1 in
        -u )           shift
                       CF_USER=$1
                       ;;
        -pw )          shift
                       CF_PASSWORD=$1
                       ;;
        -o )           shift
                       CF_ORG=$1
                       ;;
        -s )           shift
                       CF_SPACE=$1
                       ;;
        -d )           shift
                       CF_DOMAIN=$1
                       ;;
        -ap )          shift
                       APP_PREFIX=$1
                       ;;
        -v )           shift
                       BUILD_VERSION=$1
                       ;;
        -sn )          shift
                       SERVICE_NAME=$1
                       ;;
        -m )           shift
                       MEMORY=$1
                       ;;
        -p )           shift
                       APP_PATH=$1
                       ;;
        -i )           shift
                       INSTANCES=$1
                       ;;
    esac
    shift
done

if [ -z $APP_PATH ]
then
  echo "!!!!!! Please supply the path to the app to be deployed !!!!!!!!!!!!!!"
  exit 1
fi

echo_msg () {
  echo ""
  echo ""
  echo "************* ${1} *************"
  echo ""

  return 0
}

## Variables used during Jenkins Build Process
APP_NAME=$APP_PREFIX-$BUILD_VERSION
HOST_NAME=$APP_PREFIX-$CF_USER-$BUILD_VERSION

## Log into PCF endpoint - Provided via Jenkins Plugin
echo_msg "Logging into Cloud Foundry"
## wget http://go-cli.s3-website-us-east-1.amazonaws.com/releases/latest/cf-linux-amd64.tgz
## tar -zxvf cf-linux-amd64.tgz
cf --version
cf login -u $CF_USER -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE -a https://api.$CF_DOMAIN --skip-ssl-validation

# ^^^^^^^^^^^^^^^^^^^^ Commands for Jenkins Script ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

echo_msg "Pushing new Microservice"
cf push $APP_NAME -p $APP_PATH -m $MEMORY -n $HOST_NAME -i 1 -t 180 --no-start
if [ ! -z "$SERVICE_NAME" ]
  then
    cf bind-service $APP_NAME $SERVICE_NAME 
fi
cf map-route $APP_NAME $CF_DOMAIN -n $APP_PREFIX-$CF_USER

echo_msg "Starting Container & Microservice"
cf start $APP_NAME

echo_msg "Performing Blue Green Deployment"
DEPLOYED_APP_NAME=$(cf apps | grep $APP_PREFIX | head -n 1 | cut -d" " -f1)
if [ ! -z "$DEPLOYED_APP_NAME" -a "$DEPLOYED_APP_NAME" != " " -a "$DEPLOYED_APP_NAME" != "$APP_NAME" ]; then
  echo "Performing zero-downtime cutover to $BUILD_VERSION"
  cf scale "$DEPLOYED_APP_NAME" -i 1
  echo "Temp sleep in script for demo purposes only!!"
  sleep 10
  cf unmap-route "$DEPLOYED_APP_NAME" $CF_DOMAIN -n $APP_PREFIX-$CF_USER
  cf delete "$DEPLOYED_APP_NAME" -f -r
fi

echo_msg "Scaling new Version to $INSTANCES instances"
if [ ! -z "$INSTANCES" ]
  then
    cf scale $APP_NAME -i $INSTANCES
fi
cf logout
