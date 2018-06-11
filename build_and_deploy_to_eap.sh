#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
set_openshift_project
delete_old_entando_service_objects
rm overlays -rf
mvn clean process-resources fabric8:deploy -Popenshift-eap -DskipTests