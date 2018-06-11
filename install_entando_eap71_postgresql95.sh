#!/usr/bin/env bash
source "$(dirname $0)/common.sh"
function import_entando_imagestreams(){
    echo_header "Importing Entando Image Streams"
    oc delete is entando-s2i-eap-71 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-eap-71.json
    oc delete is entando-s2i-postgresql-95 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-postgresql-95.json
}


function create_entando_application(){
    echo_header "Recreating Entando 5 Application config." 2> /dev/null

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
            -p HOSTNAME_HTTPS="$(get_property application.baseurl.secure.hostname)" \
            -p HOSTNAME_HTTP="$(get_property application.baseurl.hostname)" \
            | oc create -f -
#            -p MAVEN_MIRROR_URL="$( oc describe route nexus -n openshift|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")" \
}
set_openshift_project
generate_expanded_properties_file
import_entando_imagestreams
recreate_secrets_and_linked_service_accounts
delete_old_entando_postgresql_objects
delete_old_entando_service_objects
create_entando_application
$(dirname $0)/deploy_webapps.sh
