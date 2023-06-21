# Red Hat Quay and Advanced Cluster Security

## __Prerequisites__
- 1x Red Hat OpenShift Platform (RHOCP4) v4.13
- 1x AWS account with a bucket storage.

## __Table of Content__
- [Installing Red Hat Quay using AWS S3 storage unmanaged storage](https://github.com/jtovarro/quay-acs-demo/blob/main/README.md#installing-red-hat-quay-using-aws-s3-storage-unmanaged-storage)
- [Manage Red Hat Quay](https://github.com/jtovarro/quay-acs-demo#manage-red-hat-quay)
- [Repository Mirroring](https://github.com/jtovarro/quay-acs-demo#repository-mirroring)
- [Proxy Pull-thru Caching](https://github.com/jtovarro/quay-acs-demo#proxy-pull-thru-caching)
- [Installing ACS](https://github.com/jtovarro/quay-acs-demo#installing-acs)
- [Deploying Red Hat Quay and ACS on Infrastructure nodes](https://github.com/jtovarro/quay-acs-demo#deploying-red-hat-quay-and-acs-on-infrastructure-nodes)
- [Tips to deploy Red Hat Quay and ACS for non-production environments](https://github.com/jtovarro/quay-acs-demo#tips-to-deploy-red-hat-quay-and-acs-for-non-production-environments)
- [References](https://github.com/jtovarro/quay-acs-demo#references)

## __Installing Red Hat Quay using AWS S3 storage unmanaged storage__
Log in you RHOCP cluster:

- Click __OperatorHub__ and search for __*Red Hat Quay*__.

![Red Hat Operator Hub](https://github.com/jtovarro/quay-acs-demo/blob/main/images/operator-hub.jpg)

- Click __install__.
  
![Quay install](https://github.com/jtovarro/quay-acs-demo/blob/main/images/quay-install.jpg)

- Take a look to the config shown, use the default namespace to install the Red Hat Quay Operator.
- Click __install__ again.

![Quay install](https://github.com/jtovarro/quay-acs-demo/blob/main/images/quay-install-2.jpg)

Once the operator is successfully installed _(it can take some minutes)_ create a namespace:

#### __NOTE:__ Log in if your are not already logged. Use your user, password and API.

```
oc login -u redhat https://api.ocp-lab-4.12.12.sandbox1795.opentlc.com:6443
```

```
oc new-project quay-enterprise
```

The standard pattern for configuring unmanaged components is:
  1) Create a config.yaml configuration file with the appropriate settings
```
mkdir ~/quay-demo
cd ~/quay-demo

cat <<EOF >> conf-aws-storage.yaml
FEATURE_USER_INITIALIZE: true
BROWSER_API_CALLS_XHR_ONLY: false
SUPER_USERS:
- quayadmin
FEATURE_USER_CREATION: true
## Enable the following if you want to use the new User Interface.
## FEATURE_UI_V2: true 
DISTRIBUTED_STORAGE_CONFIG:
  s3Storage:
    - S3Storage
    - host: s3.aws_region.amazonaws.com
      s3_access_key: your_access_key
      s3_secret_key: your_secret_key
      s3_bucket: your_bucket
      storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - s3Storage
EOF
```

#### __NOTE:__ In this repository, we are configuring the object storage as unmanaged, specifically using AWS S3 storage. However, it can also be configured with other unmanaged S3 storage options, as well as managed storage like ODF. See the [documentation](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/deploying_the_red_hat_quay_operator_on_openshift_container_platform/operator-preconfigure).

   2) Create a secret using the configuration file.
```
oc create secret generic --from-file config.yaml=./conf-aws-storage.yaml config-bundle-secret -n quay-enterprise
```

   3) Deploy the Quay Registry CRD identifying the unmanaged components, in this case the Object Storage.

```
cat <<EOF >> quayregistry.yaml
apiVersion: quay.redhat.com/v1
kind: QuayRegistry
metadata:
  name: registry
  namespace: quay-enterprise
spec:
  configBundleSecret: config-bundle-secret
  components:
    - kind: objectstorage
      managed: false
EOF
```

```
oc create -n quay-enterprise -f quayregistry.yaml
```

Take a look to the pods in quay-enterprise namespace, you should now see all the components running as pods.
```
oc get pods -n quay-enterprise

NAME                                                READY   STATUS        RESTARTS       AGE
quay-operator.v3.8.8-76546dc949-nz28x               1/1     Running       0              129m
quay-registry-clair-app-577d85bd86-89xkb            1/1     Running       0              126m
quay-registry-clair-postgres-674d6c879b-zxqjw       1/1     Running       1              127m
quay-registry-quay-app-5964c8f454-79xqv             1/1     Running       0              126m
quay-registry-quay-app-upgrade-pvvx8                0/1     Completed     0              127m
quay-registry-quay-config-editor-685b7b9f76-8bng8   1/1     Running       0              126m
quay-registry-quay-database-777f86cf96-gk88d        1/1     Running       0              127m
quay-registry-quay-mirror-cfc4bcdf-5xztx            1/1     Running       0              125m
quay-registry-quay-mirror-cfc4bcdf-v9mfr            1/1     Running       0              29s
quay-registry-quay-redis-69ccdc9dc-fvxpf            1/1     Running       0              127m
```

## __Manage Red Hat Quay__

Let's check the Red Hat Quay UI and make our first log in:
```
oc get route quay-registry-quay -o jsonpath={.spec.host} -n quay-enterprise
```

  1) First it is necessary to create an admin user, previously in our _config.yaml_, we allowed __quayadmin__ as superuser, so let's create this user.

#### __NOTE:__ Once this first user is created, change the __FEATURE_USER_CREATION: false__ to in the config-budle-secret secret used previously in to install Red Hat Quay. This feature enables/desables de UI to create users. 

![Create a user](https://github.com/jtovarro/quay-acs-demo/blob/main/images/quay-user.jpg)

![Create a user](https://github.com/jtovarro/quay-acs-demo/blob/main/images/quay-user-2.jpg)

  2) _quayadmin_ as superuser is allowed to create more users and organizations.
    - Click __Create a New Organization__, type __redhat__ as organization name, and click __Create Organization__.

![Create a new organization](https://github.com/jtovarro/quay-acs-demo/blob/main/images/organization.jpg)

  3) In this brand new organization it is possible to see: repositories, team and membership, robot accounts, default permissions, logs, applications and organization settings.

![New Organization dashboard](https://github.com/jtovarro/quay-acs-demo/blob/main/images/organization-dashboard.png)
 
  4) As organization it is possible to create different teams and users with different permissions to access the container images. Try it by yourself, creating teams and users as members.

  5) Click __Create New Repository__, type __rhel__ as repository name, choose _Private_ as repository visibility and click __Create Private Repository__.

![Brand new repository](https://github.com/jtovarro/quay-acs-demo/blob/main/images/repository.jpg)
 
  6) In __rhel__ repository click __Settings__. Here it is possible to add user permissions. 

![Settings](https://github.com/jtovarro/quay-acs-demo/blob/main/images/setting-repo.jpg)

  8) Let's push two diferent [Certified Container Images](https://catalog.redhat.com/software/containers/search?p=1&q=ubi). Select __ubi7__ and __ubi9__ containers images, then click __Get this image__ and copy the appropiate command to make a pull.

![Red Hat Container images](https://github.com/jtovarro/quay-acs-demo/blob/main/images/container-image.jpg)

```
podman pull registry.access.redhat.com/ubi7:7.9-1074
podman pull registry.access.redhat.com/ubi9:9.2-489
```

  9) Tag the container images.
```
podman tag registry.access.redhat.com/ubi7:7.9-1074 quay-registry-quay-domain.example.com/rhel/ubi7:7.9-1074
podman tag registry.access.redhat.com/ubi9:9.2-489 quay-registry-quay-domain.example.com/rhel/ubi9:9.2-489
```

  10) Push the images to the Red Hat Quay registry:

```
podman login quay-registry-domain.example.com
podman push quay-registry-quay-domain.example.com/rhel/ubi9:9.2-489 docker://quay-registry-domain.example.com/redhat/rhel:9.2-489 --remove-signatures --tls-verify=false
podman push quay-registry-quay-domain.example.com/rhel/ubi7:7.9-1074 docker://quay-registry-domain.example.com/redhat/rhel:7.9-1074 --remove-signatures --tls-verify=false
```

  11) In the __rhel__ repository in Red Hat Quay, check __Repository tags__, you will find there the two tags corresponding to the previous push command.

![Container images](https://github.com/jtovarro/quay-acs-demo/blob/main/images/tags.png)

  12) Check the __Security scan__ dashboard, this dashboard provides with an easy access to vulnerabilities found, their severity, and if they are fixed in the next versions.

![Image vulnerabilities](https://github.com/jtovarro/quay-acs-demo/blob/main/images/vulnerabilities.png)

## __Repository Mirroring__

Red Hat Quay allows you to mirroring from public or private repositories. Only _pull_ are allowed from mirrored repositories, to push to this repository a _robot account_ will take on this role. 

  1) Click __Create New Repository__, type __mirror-nginx__ as repository name, choose _Private_ as repository visibility and click __Create Private Repository__.

![Mirroring repository](https://github.com/jtovarro/quay-acs-demo/blob/main/images/new-repo.jpg)

  2) Go to __Settings__, and change _Repository State_ from _normal_ to __mirror__.

![Mirror state](https://github.com/jtovarro/quay-acs-demo/blob/main/images/setting-mirror.jpg)

  3) As mirroring configuration add the following:
       - Registry Location: bitnami/nginx
       - Tags: 1.1*,1.20*
       - Start Date: Today
       - Sync Interval: 10 seconds
       - Create robot account with name _quay_workshop_robot_
       - Enable mirror

![Mirroring nginx repository](https://github.com/jtovarro/quay-acs-demo/blob/main/images/mirroring-config.jpg)

  4) Click __Sync now__. Now in the __Repository Tags__ section you will start to the the new container images added mirrored from _bitnami/nginx_, with the static __Security Scan__ from _Clair_.

![Mirrored tags](https://github.com/jtovarro/quay-acs-demo/blob/main/images/mirror-tags.png)

## __Proxy Pull-thru caching__

This feature is available for Red Hat Quay v3.7 and above, it allows Quay to be used as transparent cache for other external registries.

  1) To enable this feature make sure that in the config file _conf-aws-storage.yaml_ __FEATURE_PROXY_CACHE: true__ is set to true.

```
cat <<EOF >> conf-aws-storage-cache.yaml
FEATURE_PROXY_CACHE: true
FEATURE_USER_INITIALIZE: true
BROWSER_API_CALLS_XHR_ONLY: false
SUPER_USERS:
- quayadmin
FEATURE_USER_CREATION: false
## Enable the following if you want to use the new User Interface.
## FEATURE_UI_V2: true 
DISTRIBUTED_STORAGE_CONFIG:
  s3Storage:
    - S3Storage
    - host: s3.aws_region.amazonaws.com
      s3_access_key: your_access_key
      s3_secret_key: your_secret_key
      s3_bucket: your_bucket
      storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - s3Storage
EOF
```

```
oc delete secret config-bundle-secret -n quay-enterprise
oc create secret generic --from-file config.yaml=./conf-aws-storage-cache.yaml config-bundle-secret -n quay-enterprise
oc get delete pods --all -n quay-enterprise
```

  2) In the Red Hat Quay UI, __Create a New Organization__ and configure it as cache for another registry.

![New-oranization](https://github.com/jtovarro/quay-acs-demo/blob/main/images/organization.jpg)

![cache organization](https://github.com/jtovarro/quay-acs-demo/blob/main/images/cache.jpg)
  
  3) Go to __Settings__, if the feature is correctly enable you will find the Proxy Cache configuration, insert the reppository you would like to have cached:

       - Remote Registry: quay.io
    
     Introduce your username and password for private repositories, in this case as it is a public repository you can skip them safely and pull the images anonymously.
  
       - Remote Registry Username: your_user
       - Remote Registry Password: your_password 

     Expiration configures the time the images will be cached, default expiration is set to 24 hours, or 86400 seconds.
  
       - Expiration: 86400

![settings-quay.io](https://github.com/jtovarro/quay-acs-demo/blob/main/images/cache-2.jpg)

  Enabling proxy cache configuration means that this organization is now _read-only_, push is not allowed or create new content, you can only pull in the organization as cache.

  4) Go to __tags__ section and check there is no images.

![tags](https://github.com/jtovarro/quay-acs-demo/blob/main/images/cache-1.jpg)

  5) Let's pull images from the cache, use your quay domain to pull the image. 

#### __NOTE:__ Make sure you already logged in podman with a user holding enough permissions to pull from the repository.

```
podman pull quay-registry-quay-quay-enterprise.apps.domain.com/cache/projectquay/clair:nightly
```

```
Trying to pull quay-registry-quay-quay-enterprise.apps.ocp-lab-4.12.12.sandbox1795.opentlc.com/cache/projectquay/clair:nightly...
Getting image source signatures
Copying blob f967357dba58 done  
Copying blob d2b5f358ecf1 done  
Copying blob 4f4fb700ef54 done  
Copying blob a44efdbfd478 done  
Copying config 89b5d8b93c done  
Writing manifest to image destination
Storing signatures
89b5d8b93ca3246ba39e153d3eb38dff1f2d3708ec5563f685460d382e517799
```

  Instead of using the quay.io/projectquay/clair:nightly image directly, you can utilize your cache repository. This cache repository will pull the container image from quay.io and cache it, making the image available in the cache registry for a specified expiration time. Every time the image is pull, the expiration time is reset.

![image cached](https://github.com/jtovarro/quay-acs-demo/blob/main/images/cache-4.jpg)

## __Installing ACS__

- Click __OperatorHub__ and search for *Advanced Cluster Security* or *ACS*

![Operator Hub](https://github.com/jtovarro/quay-acs-demo/blob/main/images/operator-hub.jpg)

- Click __install__.

![ACS install config](https://github.com/jtovarro/quay-acs-demo/blob/main/images/acs-install-2.jpg)

- Take a look to the config shown, use the default namespace *rhacs-operator* to install the RH Quay Operator.
- Click __install__ again.

![ACS installing](https://github.com/jtovarro/quay-acs-demo/blob/main/images/acs-install-1.jpg)

Once the operator is successfuly installed _(it can take some minutes)_ create a namespace:

```
oc new-project stackrox
```

Follow the next steps to complete the ACS configuration and add the local cluster to the ACS clusters resource list:

  1) Create a __Central__ instance.

```
cat <<EOF >> central-instance.yaml
apiVersion: platform.stackrox.io/v1alpha1
kind: Central
metadata:
  name: stackrox-central-services
  namespace: stackrox
spec:
  central:
    exposure:
      loadBalancer:
        enabled: false
        port: 443
      nodePort:
        enabled: false
      route:
        enabled: true
    db:
      isEnabled: Default
      persistence:
        persistentVolumeClaim:
          claimName: central-db
    persistence:
      persistentVolumeClaim:
        claimName: stackrox-db
  egress:
    connectivityPolicy: Online
  scanner:
    analyzer:
      scaling:
        autoScaling: Enabled
        maxReplicas: 5
        minReplicas: 2
        replicas: 3
    scannerComponent: Enabled
EOF
```

```
oc create -f central-instance.yaml -n stackrox
```

  2) Wait for all the pods in _stackrox_ namespace to become ready and running.

```
oc get pods -n stackrox

NAME                                 READY   STATUS    RESTARTS         AGE
central-66df9d9c79-9dlcv             1/1     Running   0                5m18s
central-db-85bb8bfbc5-7p8bl          1/1     Running   0                5m18s
scanner-58cf565974-4ppsc             1/1     Running   0                5m18s
scanner-58cf565974-tffh5             1/1     Running   0                5m18s
scanner-db-68cccfc7d5-sdskp          1/1     Running   0                5m18s
```

  3) Once all the pods are running go to the ACS dashboard.

```
oc get route central -o jsonpath={.spec.host} -n stackrox
```

![ACS log in console](https://github.com/jtovarro/quay-acs-demo/blob/main/images/acs-login.png)

  4) To access to ACS you will find Admin credential info in the Central instance, use __admin__ as user and go to the _Data_ section in the __central-htpasswd__ secret for the password.

![Central instance](https://github.com/jtovarro/quay-acs-demo/blob/main/images/central.jpg)

![Secret](https://github.com/jtovarro/quay-acs-demo/blob/main/images/central-2.jpg)

![Reveal password](https://github.com/jtovarro/quay-acs-demo/blob/main/images/central-3.jpg)

  5) In the ACS dashboard fo to __Platform Configuration__, then __Integrations__ and search for _Authentication Tokens_ at the end of the page.

![Adding the cluster to ACS](https://github.com/jtovarro/quay-acs-demo/blob/main/images/config-acs.jpg)

  6) Click __Cluster Init Bundle__.

![Integrations](https://github.com/jtovarro/quay-acs-demo/blob/main/images/config-acs-2.jpg)

![Cluster Init Bundle](https://github.com/jtovarro/quay-acs-demo/blob/main/images/config-acs-3.jpg)

  7) Click __Generate bundle__, type __quay-cluster__ as name, and __Download Kubernetes secrets file__. 

![Generate bundle](https://github.com/jtovarro/quay-acs-demo/blob/main/images/config-acs-4.png)

![Download Kubernetes Secret file](https://github.com/jtovarro/quay-acs-demo/blob/main/images/config-acs-6.jpg)

  Then apply the secret file downloaded.

```
oc create -f my-cluster-cluster-init-secrets.yaml -n stackrox
```

  7) Last step here is to create a __Secured Cluster__ instance.

#### __NOTE:__ Do not forget to add the 443 port at the end of the _central endpoint_.

```
cat <<EOF >> secured-cluster-instance.yaml
apiVersion: platform.stackrox.io/v1alpha1
kind: SecuredCluster
metadata:
  name: stackrox-secured-cluster-services
  namespace: stackrox
spec:
  auditLogs:
    collection: Auto
  admissionControl:
    listenOnUpdates: true
    bypass: BreakGlassAnnotation
    contactImageScanners: DoNotScanInline
    listenOnCreates: true
    timeoutSeconds: 20
    listenOnEvents: true
  scanner:
    analyzer:
      scaling:
        autoScaling: Enabled
        maxReplicas: 5
        minReplicas: 2
        replicas: 3
    scannerComponent: AutoSense
  perNode:
    collector:
      collection: EBPF
      imageFlavor: Regular
    taintToleration: TolerateTaints
  clusterName: my-cluster
  centralEndpoint: 'central-stackrox.domain.example.com:443'
EOF
```

```
oc create -f secured-cluster-instance.yaml
```

  8) Now you should see a cluster added to ACS (it can take some minutes). Check that the _admission_, _collector_ and _scanner_ pods are running.

```
oc get pods -n stackrox

NAME                                 READY   STATUS    RESTARTS   AGE
admission-control-6b5dd59bc6-5xncp   1/1     Running   0          28s
admission-control-6b5dd59bc6-bjk6c   1/1     Running   0          28s
admission-control-6b5dd59bc6-gklnw   1/1     Running   0          28s
central-66df9d9c79-9dlcv             1/1     Running   0          11m
central-db-85bb8bfbc5-7p8bl          1/1     Running   0          11m
collector-6gzpm                      3/3     Running   0          28s
collector-l76tw                      3/3     Running   0          28s
collector-v9sd2                      3/3     Running   0          28s
scanner-58cf565974-4ppsc             1/1     Running   0          11m
scanner-58cf565974-tffh5             1/1     Running   0          11m
scanner-db-68cccfc7d5-sdskp          1/1     Running   0          11m
sensor-758588f75f-mqtjw              1/1     Running   0          28s
``` 

  9) Click __Compliance__.

![Compliance](https://github.com/jtovarro/quay-acs-demo/blob/main/images/compliance.jpg)

  10) Click __Scan Environment__.

![Scan Environment](https://github.com/jtovarro/quay-acs-demo/blob/main/images/compliance-2.jpg)

  Once the scan is completed you should see in the dashbord metrics about compliance.

![Scan completed](https://github.com/jtovarro/quay-acs-demo/blob/main/images/compliance-3.png)

### __Deploying Red Hat Quay and ACS on Infrastructure nodes__

By default, Quay-related pods are placed on arbitrary worker nodes when using the Operator to deploy the registry. The OpenShift Container Platform documentation shows how to use machine sets to configure nodes to only host infrastructure components (see [Documentation](https://docs.openshift.com/container-platform/4.13/machine_management/creating-infrastructure-machinesets.html)).

Applying a taint to the infrastructure nodes and a toleration for that taint to all infrastructure components will guarantee that only those resources will be scheduled on the Infrastructure nodes. Taints can prevent workloads that do not have a matching toleration from running on particular nodes.

#### __NOTE:__ Some workloads such as daemonsets still need to be scheduled on these particular nodes. In this case, those workloads need a universal toleration.

It is possible to [Manually set labels and taints on Infrastructure Nodes](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/deploying_the_red_hat_quay_operator_on_openshift_container_platform/advanced-concepts#operator-deploy-infrastructure), for this scenario we will be using machine sets.

  1) Run the following commands to get the _Infrastructure ID_ from your cluster, then change them in the machine set.

```
oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster
```

#### __NOTE:__ In a production deployment, it is recommended that you deploy at least three compute machine sets to hold infrastructure components. Each of these nodes can be deployed to different availability zones for high availability. For example, create three (3) YAML manifest infrastructure-ms-1a.yaml, infrastructure-ms-1b.yaml and infrastructure-ms-1c.yaml changing the availability zones.

```
cat <<EOF >> infrastructure-ms-1a.yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: <infrastructure_id> 
  name: <infrastructure_id>-infra-<zone> 
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: <infrastructure_id> 
      machine.openshift.io/cluster-api-machineset: <infrastructure_id>-infra-<zone> 
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: <infrastructure_id> 
        machine.openshift.io/cluster-api-machine-role: infra 
        machine.openshift.io/cluster-api-machine-type: infra 
        machine.openshift.io/cluster-api-machineset: <infrastructure_id>-infra-<zone> 
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: "" 
      providerSpec:
        value:
          ami:
            id: ami-0b2586f09f16dd949
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
            - ebs:
                iops: 0
                volumeSize: 120
                volumeType: gp2
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: <infrastructure_id>-worker-profile 
          instanceType: m6i.4xlarge
          kind: AWSMachineProviderConfig
          placement:
            availabilityZone: <zone> 
            region: <region> 
          securityGroups:
            - filters:
                - name: tag:Name
                  values:
                    - <infrastructure_id>-worker-sg 
          subnet:
            filters:
              - name: tag:Name
                values:
                  - <infrastructure_id>-private-<zone> 
          tags:
            - name: kubernetes.io/cluster/<infrastructure_id> 
              value: owned
            - name: <custom_tag_name> 
              value: <custom_tag_value> 
          userDataSecret:
            name: worker-user-data
      taints: 
        - key: node-role.kubernetes.io/infra
          effect: NoSchedule
EOF
```

```
oc create -f infrastructure-ms-1a.yaml -n openshift-machine-api
```

Once the machine sets are created, you should have three (3) new nodes with __node-role.kubernetes.io/infra: ""__ and __"node-role.kubernetes.io/worker: ""__ labels. Also these nodes will have a taint to avoid workloads to be scheduled on infra nodes. To avoid this restriction and deploy Red Hat Quay and ACS on infra nodes it is possible to use taint tolerations:

#### __NOTE:__ If you have already deployed Quay using the Quay Operator, remove the installed operator and any specific namespace(s) you created for the deployment.

  2) Create a new project specifying a node selector and taint toleration to deploy __Red Hat Quay__ workloads on infrastructure nodes.

```
cat <<EOF >> quay-enterprise-ns.yaml
kind: Project
apiVersion: project.openshift.io/v1
metadata:
  name: quay-enterprise
  annotations:
    openshift.io/node-selector: 'node-role.kubernetes.io/infra='
    scheduler.alpha.kubernetes.io/defaultTolerations: >-
      [{"operator": "Exists", "effect": "NoSchedule", "key":
      "node-role.kubernetes.io/infra"}
      ]
EOF
```

```
oc apply -f quay-enterprise-ns.yaml
```

  Any subsequent resources created in the quay-registry namespace should now be scheduled on the dedicated infrastructure nodes.

  3) Follow the same steps seen previously in [Installing Red Hat Quay](https://github.com/jtovarro/quay-acs-demo/blob/main/README.md#installing-red-hat-quay-using-aws-s3-storage-unmanaged-storage). Any subsequent resources created in the _quay-enterprise_ namespace should now be scheduled on the dedicated infrastructure nodes.

  4) Create a new project specifying a node selector and taint toleration to deploy __ACS__ workloads on infrastructure nodes.

```
cat <<EOF >> quay-enterprise-ns.yaml
kind: Project
apiVersion: project.openshift.io/v1
metadata:
  name: stackrox
  annotations:
    openshift.io/node-selector: 'node-role.kubernetes.io/infra='
    scheduler.alpha.kubernetes.io/defaultTolerations: >-
      [{"operator": "Exists", "effect": "NoSchedule", "key":
      "node-role.kubernetes.io/infra"}
      ]
EOF
```

  5) Follow the same steps seen previously in [Installing ACS](https://github.com/jtovarro/quay-acs-demo#installing-acs). Any subsequent resources created in the _stackrox_ namespace should now be scheduled on the dedicated infrastructure nodes.

### __Tips to deploy Red Hat Quay and ACS for non-production environments__

Red Hat Quay alongside ACS are cpu and memory demanding so if you want to try it, __for non production environments__ it is possible to reduce their cpu and memory consume with the following:

#### __NOTE:__ Check in the MachineSet that the cluster has at least 4 CPU and 16GB RAM.

```
oc get machineset -A
oc get machineset ocp-lab-4-12-12-fv9z6-worker-eu-central-1a -n openshift-machine-api -oyaml | grep vCPU
oc get machineset ocp-lab-4-12-12-fv9z6-worker-eu-central-1a -n openshift-machine-api -oyaml | grep memoryMb
```

  1) Install Red Hat Quay in a _single_ namespace instead of _cluster wide_, for example install the operator in quay-enterprise namespace.
     
  2) Disable _monitoring_ and _horizontalpodautoscaler_ components from Quay Registry instance.

```
  components:
    - kind: objectstorage
      managed: false
    - kind: clair
      managed: true
    - kind: mirror
      managed: true
    - kind: monitoring
      managed: false
    - kind: tls
      managed: true
    - kind: quay
      managed: true
    - kind: clairpostgres
      managed: true
    - kind: postgres
      managed: true
    - kind: redis
      managed: true
    - kind: horizontalpodautoscaler
      managed: false
    - kind: route
      managed: true
```

  3) Reduce _quay-registry-clair-app_, _quay-registry-quay-app_ and _quay-registry-quay-mirror_ HPA replicas min and max to 1:

```
oc get hpa -A

NAMESPACE         NAME                        REFERENCE                              TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
quay-enterprise   quay-registry-clair-app     Deployment/quay-registry-clair-app     18%/90%, 0%/90%   1         1         1          2d5h
quay-enterprise   quay-registry-quay-app      Deployment/quay-registry-quay-app      44%/90%, 0%/90%   1         1         1          2d5h
quay-enterprise   quay-registry-quay-mirror   Deployment/quay-registry-quay-mirror   29%/90%, 0%/90%   1         1         1          2d5h
```

---
### References
[1] [Quay install](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/deploying_the_red_hat_quay_operator_on_openshift_container_platform/operator-preconfigure)

[2] [Repository mirroring](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/manage_red_hat_quay/repo-mirroring-in-red-hat-quay#arch-mirroring-intro)

[3] [ACS Install](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_security_for_kubernetes/3.71/html/installing/install-ocp-operator#install-secured-cluster-operator_install-ocp-operator)

[4] [Infrastructure Nodes in OpenShift](https://access.redhat.com/solutions/5034771)

[5] [Deploying Quay on infrastructure nodes](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/deploying_the_red_hat_quay_operator_on_openshift_container_platform/advanced-concepts#operator-deploy-infrastructure)

[6] [Proxy Pull-thru Caching demo](https://www.youtube.com/watch?v=oVlRDuCD6ic)

## Author

Juan Carlos Tovar @RedHat
