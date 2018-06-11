#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
set_openshift_project
delete_old_entando_postgresql_objects
recreate_secrets_and_linked_service_accounts
rm overlays -rf
mvn clean process-resources fabric8:deploy -Popenshift-postgresql -DskipTests
