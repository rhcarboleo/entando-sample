ENTANDO_OPS_HOME=~/Code/entando/entando-ops/

function get_property {
    echo "$(cat src/main/filters/filter-openshift.properties | grep -oP "(?<=profile\.$1\=).+$")"
}
function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}
function import_imagestreams() {
    echo_header "Importing Image Streams"
    oc delete is rhpam70-businesscentral-openshift 2> /dev/null
    oc delete is rhpam70-businesscentral-monitoring-openshift 2> /dev/null
    oc delete is rhpam70-kieserver-openshift 2> /dev/null
    oc delete is rhpam70-controller-openshift 2> /dev/null
    oc delete is rhpam70-smartrouter-openshift 2> /dev/null
    oc delete is rhpam70-businesscentral-indexing-openshift 2> /dev/null
    oc create -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/rhpam70-image-streams.yaml
    oc delete is entando-s2i-eap-71 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-eap-71.json
    oc delete is entando-s2i-postgresql-95 2> /dev/null
    oc create -f $ENTANDO_OPS_HOME/Openshift/image-streams/entando-postgresql-95.json
}
function pull_docker_images(){
    echo_header "Pulling Docker Images"
    docker pull registry.access.redhat.com/rhpam-7/rhpam70-businesscentral-openshift:1.0
    docker pull registry.access.redhat.com/rhpam-7/rhpam70-kieserver-openshift:1.0
    #docker pull entando/entando-fabric8s2i-eap-71:5.0.1
    #docker pull entando/entando-fabric8s2i-postgresql-95:5.0.1
}

function create_secrets_and_linked_service_accounts() {
    echo_header "Creating PAM Central keystore secret."
    oc delete sa businesscentral-service-account 2> /dev/null
    oc delete secret businesscentral-app-secret 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml | oc create -f -
    oc create serviceaccount businesscentral-service-account
    sleep 0.5 #to give Openshift time to apply changes in time
    oc secrets link --for=mount businesscentral-service-account businesscentral-app-secret

    echo_header "Creating KIEServer keystore secret."
    oc delete secret kieserver-app-secret 2> /dev/null
    oc delete sa kieserver-service-account 2> /dev/null
    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/rhpam70-dev/example-app-secret-template.yaml -p SECRET_NAME=kieserver-app-secret | oc create -f -
    oc create serviceaccount kieserver-service-account
    sleep 0.5
    oc secrets link --for=mount kieserver-service-account kieserver-app-secret

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
  username: "$(get_property database.username)"
  password: "$(get_property database.password)"
EOF

    echo_header "Creating KIEServer secret."
    oc delete secret "$(get_property application.name)-kieserver-secret" 2> /dev/null
    cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: "$(get_property application.name)-kieserver-secret"
stringData:
  url: "http://$(get_property application.name)-kieserver.svc/kie-server"
  username: "$(get_property kieserver.username)"
  password: "$(get_property kieserver.password)"
EOF

}

function create_kie_application() {
    echo_header "Creating Process Automation Manager 7 Application config."

    oc process -f https://raw.githubusercontent.com/jboss-container-images/rhpam-7-openshift-image/7.0.0.GA/templates/rhpam70-authoring.yaml \
            -p APPLICATION_NAME="$(get_property application.name)" \
            -p BUSINESS_CENTRAL_HTTPS_SECRET=businesscentral-app-secret \
            -p KIE_SERVER_HTTPS_SECRET=kieserver-app-secret \
            -p IMAGE_STREAM_NAMESPACE="$(get_property openshift.project)" \
            -p IMAGE_STREAM_TAG="1.0" \
            -p KIE_ADMIN_USER="pamAdmin" \
            -p KIE_ADMIN_PWD="redhatpam1!" \
            -p KIE_SERVER_CONTROLLER_USER="$(get_property kieserver.username)" \
            -p KIE_SERVER_CONTROLLER_PWD="$(get_property kieserver.password)" \
            -p KIE_SERVER_USER="$(get_property kieserver.username)" \
            -p KIE_SERVER_PWD="$(get_property kieserver.password)" \
            -p BUSINESS_CENTRAL_MEMORY_LIMIT="2Gi" \
            | oc create -f -
#           -p MAVEN_MIRROR_URL="$( oc describe route nexus -n openshift|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")" \

}
function create_entando_application(){
    echo_header "Creating Entando 5 Application config."
    oc delete service "entando-sample"
    oc delete service "secure-entando-sample"
    oc delete service "entando-sample-postgresql"
    oc delete service "entando-sample-ping"
    oc delete route "entando-sample"
    oc delete route "secure-entando-sample"
    oc delete imagestream "entando-sample-postgresql"
    oc delete buildconfig "entando-sample"
    oc delete buildconfig "entando-sample-postgresql"
    oc delete deploymentconfig "entando-sample-postgresql"
    oc delete persistentvolumeclaim "entando-sample-postgresql-claim"
    oc delete imagestream "entando-sample"
    oc delete deploymentconfig "entando-sample"

    oc process -f $ENTANDO_OPS_HOME/Openshift/templates/entando-eap-71-with-postgresql-95.yml \
            -p SOURCE_REPOSITORY_URL=$(git remote -v | grep -oP "(?<=origin\s).+(?=\s\(fetch\)$)") \
            -p KIESERVER_SECRET="$(get_property application.name)-kieserver-secret" \
            -p DB_SECRET="$(get_property application.name)-db-secret" \
            -p ENTANDO_PORT_DB_JNDI_NAME="java:jboss/datasources/$(get_property application.name)PortDataSource" \
            -p ENTANDO_SERV_DB_JNDI_NAME="java:jboss/datasources/$(get_property application.name)ServDataSource" \
            -p ENTANDO_PORT_DATABASE="$(get_property database.name.portdb)" \
            -p ENTANDO_SERV_DATABASE="$(get_property database.name.servdb)" \
            -p HTTPS_SECRET="entando-app-secret" \
            -p JGROUPS_ENCRYPT_SECRET="entando-app-secret" \
            | oc create -f -
#            -p MAVEN_MIRROR_URL="$( oc describe route nexus -n openshift|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")" \
}


#import_imagestreams
#pull_docker_images
#create_secrets_and_linked_service_accounts
#create_kie_application
create_entando_application