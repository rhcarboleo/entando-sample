#!/usr/bin/env bash
export ENTANDO_OPS_HOME=~/Code/entando/entando-ops/
export OPENSHIFT_PROJECT=$(cat src/main/filters/filter-openshift-eap.properties | grep -oP "(?<=profile\.openshift\.project\=).+$")
function generate_expanded_properties_file(){
#for the time being we are only really interest in some basic properties, but in future we may
#want to exploit property expansion more in which case we may need to generate per profile
   mvn resources:copy-resources@generate-filter-properties -Popenshift-eap
}
function get_property {
    echo "$(cat $(dirname $0)/target/filters/filter-openshift-eap.properties | grep -oP "(?<=^profile\.$1\=).+$")"
}
function echo_header() {
    echo
    echo "########################################################################"
    echo $1
    echo "########################################################################"
}
function set_openshift_project(){
    oc whoami 2> /dev/null
    if ! [[ $? -eq 0  ]]; then
        echo "Please first log into Openshift using oc login -u <<your username>>"
        exit 1;
    fi
    if oc project ${OPENSHIFT_PROJECT}; then
      echo "Welcome to ${OPENSHIFT_PROJECT}";
    else
      oc new-project ${OPENSHIFT_PROJECT};
    fi;
}
function recreate_secrets_and_linked_service_accounts() {
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
  url: "http://$(get_property application.name)-kieserver.${OPENSHIFT_PROJECT}.svc:8080/kie-server"
  username: "$(get_property kieserver.username)"
  password: "$(get_property kieserver.password)"
EOF

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
    echo_header "Deleting old Entando Service Objects." 2> /dev/null
    oc delete service "$(get_property application.name)" 2> /dev/null
    oc delete service "secure-$(get_property application.name)" 2> /dev/null
    oc delete service "$(get_property application.name)-ping" 2> /dev/null
    oc delete route "$(get_property application.name)" 2> /dev/null
    oc delete route "secure-$(get_property application.name)" 2> /dev/null
    oc delete imagestream "$(get_property application.name)" 2> /dev/null
    oc delete deploymentconfig "$(get_property application.name)" 2> /dev/null
    oc delete bc "$(get_property application.name)-s2i" 2> /dev/null
    #oc delete buildconfig "$(get_property application.name)" 2> /dev/null
}
function deploy_webapps(){
    APP_NAME="$(get_property application.name)"
    ENTANDO_SERVICE_URL=$(oc describe route $APP_NAME|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")
    ENTANDO_SERVICE_URL=http://$ENTANDO_SERVICE_URL/entando-sample
    ENTANDO_VERSION=5.0.0
    oc delete service "$APP_NAME-mapp-engine-admin-app" 2> /dev/null
    oc delete dc "$APP_NAME-mapp-engine-admin-app" 2> /dev/null
    oc delete route "$APP_NAME-mapp-engine-admin-app" 2> /dev/null
    oc new-app --name "$APP_NAME-mapp-engine-admin-app" --docker-image entando/mapp-engine-admin-app-openshift:$ENTANDO_VERSION -e DOMAIN=$ENTANDO_SERVICE_URL
    oc expose svc "$APP_NAME-mapp-engine-admin-app"

    oc delete service "$APP_NAME-app-builder" 2> /dev/null
    oc delete dc "$APP_NAME-app-builder" 2> /dev/null
    oc delete route "$APP_NAME-app-builder" 2> /dev/null
    oc new-app --name "$APP_NAME-app-builder" --docker-image entando/app-builder-openshift:$ENTANDO_VERSION -e DOMAIN=$ENTANDO_SERVICE_URL
    oc expose svc "$APP_NAME-app-builder"
}