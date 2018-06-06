source set_openshift_project.sh
ENTANDO_SERVICE_URL=$(oc describe route entando-sample-service|grep -oP "(?<=Requested\sHost:\t\t)[^ ]+")
ENTANDO_SERVICE_URL=http://$ENTANDO_SERVICE_URL/entando-sample
ENTANDO_VERSION=5.0.0
oc new-app --name entando-sample-mapp-engine-admin-app --docker-image entando/mapp-engine-admin-app-openshift:$ENTANDO_VERSION -e DOMAIN=$ENTANDO_SERVICE_URL
oc expose svc entando-sample-mapp-engine-admin-app
oc new-app --name entando-sample-app-builder --docker-image entando/app-builder-openshift:$ENTANDO_VERSION -e DOMAIN=$ENTANDO_SERVICE_URL
oc expose svc entando-sample-app-builder
