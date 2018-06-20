#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
apply_maven_filters openshift-postgresql
set_openshift_project
APPLICATION_NAME=$(get_property application.name)
echo $APPLICATION_NAME
oc delete persistentvolumeclaim "$(get_property application.name)-postgresql-claim" 2> /dev/null
cat <<EOF | oc create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APPLICATION_NAME}-postgresql-claim
  labels:
    application: ${APPLICATION_NAME}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
recreate_secrets_and_linked_service_accounts
rm overlays -rf
oc start-build "$APPLICATION_NAME-postgresql-s2i" --from-dir .
