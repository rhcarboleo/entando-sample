#!/usr/bin/env bash
source $(dirname $0)/common.sh
set_openshift_project
SERVICE_NAME="$(get_property application.name)-nexus"
oc delete imagestream $SERVICE_NAME 2> /dev/null
oc delete deploymentconfig $SERVICE_NAME 2> /dev/null
oc delete service $SERVICE_NAME 2> /dev/null
oc delete route $SERVICE_NAME 2> /dev/null
oc delete persistentvolumeclaim "nexus-pv" 2> /dev/null
oc process -f $ENTANDO_OPS_HOME/Openshift/templates/nexus-with-entando-dependencies.yml \
    -p SERVICE_NAME=$SERVICE_NAME \
    | oc create -f -