#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
set_openshift_project
rm overlays -rf
mvn clean process-resources fabric8:deploy -Popenshift-wildfly -DskipTests