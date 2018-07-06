eval $(minishift docker-env)
IMAGES=( "entando/entando-eap71-quickstart-openshift" "entando/app-builder-openshift" )
for IMAGE in "${IMAGES[@]}"
do
  echo "Pulling image $IMAGE:5.0.1"
  docker pull $IMAGE:5.0.1
done
docker pull registry.access.redhat.com/rhpam-7/rhpam70-businesscentral-openshift:1.0
docker pull registry.access.redhat.com/rhpam-7/rhpam70-kieserver-openshift:1.0
