#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
function import_entando_imagestreams(){
    echo_header "Importing Entando Image Streams"
    oc delete is entando-s2i-eap-71 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-eap-71.json
    oc delete is entando-s2i-postgresql-95 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-postgresql-95.json
}
function create_secrets_and_linked_service_accounts() {
    echo_header "Creating Entando keystore secret."
    oc delete secret entando-app-secret 2> /dev/null
    oc delete sa entando-service-account 2> /dev/null
    oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-app-secret.yml -p SECRET_NAME=entando-app-secret | oc create -f -
#Ampie: Some voodoo repeat here. Figure out why we're doing this
    oc create serviceaccount entando-service-account
    sleep 0.5
    oc secrets link --for=mount entando-service-account entando-app-secret

    echo_header "Creating Postgresql secret."
    oc delete secret "$(get_property application.name)-db-secret" 2> /dev/null
    cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: "$(get_property application.name)-db-secret"
stringData:
  jdbcUrl: "jdbc:postgresql://$(get_property application.name)-postgresql.${OPENSHIFT_PROJECT}.svc:5432/"
  username: "$(get_property database.username)"
  password: "$(get_property database.password)"
EOF
    echo "password=$(get_property database.password)"
    echo_header "Creating KIEServer secret."
    oc delete secret "$(get_property application.name)-kieserver-secret" 2> /dev/null
    cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: "$(get_property application.name)-kieserver-secret"
stringData:
  url: "http://$(get_property application.name)-kieserver.${OPENSHIFT_PROJECT}.svc/kie-server"
  username: "$(get_property kieserver.username)"
  password: "$(get_property kieserver.password)"
EOF

}
function create_entando_application(){
    echo_header "Recreating Entando 5 Application config." 2> /dev/null
    oc delete service "$(get_property application.name)" 2> /dev/null
    oc delete service "secure-$(get_property application.name)" 2> /dev/null
    oc delete service "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete service "$(get_property application.name)-ping" 2> /dev/null
    oc delete route "$(get_property application.name)" 2> /dev/null
    oc delete route "secure-$(get_property application.name)" 2> /dev/null
    oc delete imagestream "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete buildconfig "$(get_property application.name)" 2> /dev/null
    oc delete buildconfig "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete deploymentconfig "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete persistentvolumeclaim "$(get_property application.name)-postgresql-claim" 2> /dev/null
    oc delete imagestream "$(get_property application.name)" 2> /dev/null
    oc delete deploymentconfig "$(get_property application.name)" 2> /dev/null
    oc delete bc "$(get_property application.name)-s2i" 2> /dev/null
    oc delete bc "$(get_property application.name)-postgresql-s2i" 2> /dev/null

    oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-eap-71-with-postgresql-95.yml \
            -p PROJECT_NAME="$OPENSHIFT_PROJECT" \
            -p APPLICATION_NAME="$(get_property application.name)" \
            -p SOURCE_REPOSITORY_URL=$(git remote -v | grep -oP "(?<=origin\s).+(?=\s\(fetch\)$)") \
            -p KIE_SERVER_SECRET="$(get_property application.name)-kieserver-secret" \
            -p DB_SECRET="$(get_property application.name)-db-secret" \
            -p ENTANDO_PORT_DB_JNDI_NAME="java:jboss/datasources/$(get_property application.name)PortDataSource" \
            -p ENTANDO_SERV_DB_JNDI_NAME="java:jboss/datasources/$(get_property application.name)ServDataSource" \
            -p ENTANDO_PORT_DATABASE="$(get_property database.name.portdb)" \
            -p ENTANDO_SERV_DATABASE="$(get_property database.name.servdb)" \
            -p HTTPS_SECRET="entando-app-secret" \
            -p JGROUPS_ENCRYPT_SECRET="entando-app-secret" \
            -p IMAGE_STREAM_NAMESPACE="$(get_property openshift.project)" \
            | oc create -f -
#            -p MAVEN_MIRROR_URL="$( oc describe route nexus -n openshift|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")" \
}
set_openshift_project
generate_expanded_properties_file
import_entando_imagestreams
create_secrets_and_linked_service_accounts
create_entando_application
