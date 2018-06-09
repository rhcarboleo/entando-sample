eval $(minishift docker-env)
IMAGES=( "entando-fabric8s2i-wildfly-12" "entando-fabric8s2i-postgresql-95" "mapp-engine-admin-app-openshift" "app-builder-openshift" )
for IMAGE in "${IMAGES[@]}"
do
  echo "Pulling image entando/$IMAGE:5.0.0"
  docker pull entando/$IMAGE:5.0.0
done
docker pull registry.access.redhat.com/rhpam-7/rhpam70-businesscentral-openshift:1.0
docker pull registry.access.redhat.com/rhpam-7/rhpam70-kieserver-openshift:1.0
