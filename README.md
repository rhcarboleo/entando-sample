#Overview
This sample project illustrates how Entando can work with the Entando JBoss EAP Quickstart Openshift Template. It requires a basic knowledge of Openshift, and would work best on an existing installation of Minishift.
#Instructions:
Please follow these instructions carefully and in the correct sequence. We also advise you to follow the 
progress of deployments on the Openshift browser console and only progress to the next step once the newly instantiated
pod is in a READY state.
1. Install and start Minishift following the instructions at <https://docs.openshift.org/latest/minishift/getting-started/installing.html>
2. Open a terminal session and log into your local Minishift cluster using the oc login command.
3. Specify the Openshift project you want to use by modifying the file: common.sh
and setting the **OPENSHIFT_PROJECT** environment variable. The default is **entando-sample**.
4. Pull the supporting Docker images by executing ./pull_images.sh. This could take a 
while - have some coffee. Some of the images are large, but optimized for the final 
deployment layer to be as thin as possible. Also note that it will point your Docker client to the
Docker Host running inside Minishift for the terminal session.
5. Deploy the RedHat Process Automation Manager Openshift Template by executing ./install_kie_authoring.sh. Monitor the progress in the
Openshift browser console until both deployments are in READY state.
6. Deploy the Entando JBoss EAP Quickstart Openshift Template by executing ./install_entando.sh. Monitor the progress in the
Openshift browser console until all deployments are in READY state.
7. Once all deployments are in READY state, navigate to the Routes section, and click on the HTTP (non-secure) route of the AppBuilder service. 
This will take you to the Entando AppBuilder browser App. You can login with the user **admin** using the password **adminadmin**
##TODO
1. Add instructions
