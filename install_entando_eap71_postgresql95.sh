#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
function calculate_default_baseurl(){
    if [ $(get_property application.baseurl.protocol) == "https" ]; then
      echo "https://$(calculate_secure_hostname)/$(get_property application.name)"
    else
      echo "http://$(calculate_insecure_hostname)/$(get_property application.name)"
    fi
}
function calculate_secure_hostname(){
    if [ $(get_property application.baseurl.protocol) == "https" ]; then
      echo $(get_property application.baseurl.hostname)
    else
      echo "secure-$(get_property application.baseurl.hostname)"
    fi
}
function calculate_insecure_hostname(){
    if [ $(get_property application.baseurl.protocol) == "http" ]; then
      echo $(get_property application.baseurl.hostname)
    else
      echo "insecure-$(get_property application.baseurl.hostname)"
    fi
}
function delete_old_entando_postgresql_objects(){
    echo_header "Deleting old Entando Postgresql Objects." 2> /dev/null
    oc delete service "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete imagestream "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete deploymentconfig "$(get_property application.name)-postgresql" 2> /dev/null
    oc delete persistentvolumeclaim "$(get_property application.name)-postgresql-claim" 2> /dev/null
    oc delete bc "$(get_property application.name)-postgresql-s2i" 2> /dev/null
    #oc delete buildconfig "$(get_property application.name)-postgresql" 2> /dev/null
}
function delete_old_entando_service_objects(){
    echo_header "Deleting old Entando Service Objects."
    oc delete service "$(get_property application.name)" 2> /dev/null
    oc delete service "secure-$(get_property application.name)" 2> /dev/null
    oc delete service "$(get_property application.name)-ping" 2> /dev/null
    oc delete route "$(get_property application.name)" 2> /dev/null
    oc delete route "secure-$(get_property application.name)" 2> /dev/null
    oc delete imagestream "$(get_property application.name)" 2> /dev/null
    oc delete deploymentconfig "$(get_property application.name)" 2> /dev/null
    oc delete bc "$(get_property application.name)-s2i" 2> /dev/null
}
function delete_old_webapp_objects(){
    echo_header "Deleting Entando WebApps."
    APP_NAME="$(get_property application.name)"
    oc delete service "$APP_NAME-mapp-engine-admin-app" 2> /dev/null
    oc delete dc "$APP_NAME-mapp-engine-admin-app" 2> /dev/null
    oc delete route "$APP_NAME-mapp-engine-admin-app" 2> /dev/null

    oc delete service "$APP_NAME-app-builder" 2> /dev/null
    oc delete dc "$APP_NAME-app-builder" 2> /dev/null
    oc delete route "$APP_NAME-app-builder" 2> /dev/null
}

function create_entando_application(){
    echo_header "Recreating Entando 5 Application config." 2> /dev/null
    NEXUS_URL=$(calculate_mirror_url)
    HOSTNAME_HTTPS=$(calculate_secure_hostname)
    HOSTNAME_HTTP=$(calculate_insecure_hostname)
    ENTANDO_BASEURL=$(calculate_default_baseurl)
    oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-eap-71-with-postgresql-95.yml \
            -p PROJECT_NAME="$OPENSHIFT_PROJECT" \
            -p APPLICATION_NAME="$(get_property application.name)" \
            -p SOURCE_REPOSITORY_URL=$(git remote -v | grep -oP "(?<=origin\s).+(?=\s\(fetch\)$)") \
            -p KIE_SERVER_SECRET="$(get_property application.name)-kieserver-secret" \
            -p DB_SECRET="$(get_property application.name)-db-secret" \
            -p ENTANDO_PORT_DATABASE="$(get_property database.name.portdb)" \
            -p ENTANDO_SERV_DATABASE="$(get_property database.name.servdb)" \
            -p HTTPS_SECRET="entando-app-secret" \
            -p ENTANDO_BASEURL=$ENTANDO_BASEURL \
            -p JGROUPS_ENCRYPT_SECRET="entando-app-secret" \
            -p IMAGE_STREAM_NAMESPACE="$OPENSHIFT_PROJECT" \
            -p HOSTNAME_HTTPS=$HOSTNAME_HTTPS \
            -p HOSTNAME_HTTP=$HOSTNAME_HTTP \
            -p MAVEN_MIRROR_URL="$NEXUS_URL" \
            | oc create -f -
}
generate_expanded_properties_file openshift
set_openshift_project
recreate_secrets_and_linked_service_accounts
delete_old_entando_postgresql_objects
delete_old_entando_service_objects
delete_old_webapp_objects
create_entando_application