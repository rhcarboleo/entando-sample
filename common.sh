#!/usr/bin/env bash
export ENTANDO_OPS_HOME=~/Code/entando/entando-ops
#Best guess for development
export STAGE=dev

export OPENSHIFT_PROJECT=$(cat src/main/filters/stage/$STAGE.properties | grep -oP "(?<=profile\.openshift\.project\=).+$")
function apply_maven_filters(){
   #Clean the project and regenerates all resources that use filters, typically just before an Openshift binary build
   echo_header "Applying the maven filters for profile $1"
   #openshift.subdomain can be unset in SIT and PROD without breaking anything
   mvn clean process-resources -P$1 -Dopenshift.subdomain=$(get_openshift_subdomain)
}

function generate_expanded_properties_file(){
   echo_header "Generating properties files for profile $1"
   #ONLY regenerates the expanded properties file
   #openshift.subdomain can be unset in SIT and PROD without breaking anything
   mvn resources:copy-resources@generate-filter-properties -P$1 -Dopenshift.subdomain=$(get_openshift_subdomain)
}
function get_property {
    echo "$(cat $(dirname $0)/target/all-filters/all-filters.properties | grep -oP "(?<=^profile\.$1\=).+$")"
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
function calculate_mirror_url(){
    APPLICATION_NAME=$(get_property application.name)
    NEXUS_URL="$( oc describe route $APPLICATION_NAME-nexus|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")"
    if [ ! -z $NEXUS_URL ]; then
        NEXUS_URL="http://$NEXUS_URL/repository/maven-public"
    fi
    echo $NEXUS_URL
}

function recreate_secrets_and_linked_service_accounts() {
#only for use on a development machine. In SIT/PROD we would probably prefer to manage the secrets separately
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
  url: "http://$(get_property application.name)-kieserver.${OPENSHIFT_PROJECT}.svc:8080"
  username: "$(get_property kieserver.username)"
  password: "$(get_property kieserver.password)"
EOF

}
function import_entando_image_streams(){
    echo_header "Importing Entando Image Streams"
    IMAGES=("app-builder-openshift" "entando-postgresql95-openshift" "entando-wildfly12-openshift" \
            "entando-eap71-openshift" "entando-tomcat8-openshift" "nexus-with-entando-dependencies")
    for IMAGE in "${IMAGES[@]}"
    do
        oc delete is $IMAGE 2> /dev/null
        oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/$IMAGE.json
    done
}

function get_openshift_subdomain(){
    #TODO also inspect openshift config: minishift openshift config view | grep
    PUBLIC_HOSTNAME=$(minishift config get public-hostname)
    if [[ $PUBLIC_HOSTNAME == "<nil>" ]]; then
       PUBLIC_HOSTNAME=$(minishift openshift config view | grep -oP "(?<=  subdomain: )[0-9\.a-zA-Z_\-]+")
       if [[ -z $PUBLIC_HOSTNAME ]]; then
          echo "$(minishift ip).nip.io"
       else
          echo $PUBLIC_HOSTNAME
       fi
    else
        echo $PUBLIC_HOSTNAME
    fi
}
