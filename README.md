# Red Hat Quay and Advanced Cluster Security

## __Prerequisites__
- 1x Red Hat OpenShift Platform (RHOCP4) v4.13
- 1x AWS account with a bucket storage.

## __Installing Red Hat Quay using AWS S3 storage unmanaged storage__
Log in you RHOCP cluster:

- Click __OperatorHub__ and search for *Red Hat Quay*.
- Click __install__.
- Take a look to the config shown, use the default namespace to install the Red Hat Quay Operator.
- Click __install__ again.

Once the operator is successfuly installed _(it can take some minutes)_ create a namespace:

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
      s3_access_key: your_acces_key
      s3_secret_key: your_secret_key
      s3_bucket: your_bucket
      storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - s3Storage
EOF
```

   2) Create a Secret using the configuration file.
```
oc create secret generic --from-file config.yaml=./conf-aws-storage.yaml config-bundle-secret -n quay-enterprise
```

   3) Deploy the Quay Registry CRD indentifying the unmanaged components, in this case the Object Storage.

#### __NOTE:__ It is possible to disable monitoring and horizontal pod autoscaler for example if you want to reduce cpu usage for the demo.

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
```

## __Manage Red Hat Quay__

Let's check the Red Hat Quay UI and make our first log in:
```
oc get route quay-registry-quay -o jsonpath={.spec.host} -n quay-enterprise
quay-registry-quay-domain.example.com
```

  1) First it is necessary to create an admin user, previously in our _config.yaml_, we allowed __quayadmin__ as superuser, so let's create this user.

  2) _quayadmin_ as superuser is allowed to create more users and organizations.
    - Click __Create a New Organization__, type __rhel__ as organization name, and click __Create Organization__.

  3) In this brand new organization it is possible to see: repositories, team and membership, robot accounts, default permissions, logs, applications and organization settings.
 
  4) As organization it is possible to create different teams and users with different permissions to access the container images. Try it by yourself, creating teams and users as members.

  5) Click __Create New Repository__, type __rhel__ as repository name, choose _Private_ as repository visibility and click __Create Private Repository__.
 
  6) In __rhel__ repository click __Settings__. Here it is possible to add user permissions. Let's push two diferent [Certified Container Images](https://catalog.redhat.com/software/containers/search?p=1&q=ubi).
     
  8) Select __ubi7__ and __ubi9__ containers images, then click __Get this image__ and copy the appropiate command to make a pull.
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

#### __NOTE:__ Learn more about --remove-signature and --tls-verify flags.
```
podman push quay-registry-quay-domain.example.com/repository/redhat/rhel/ubi9:9.2-489 docker://quay-registry-domain.example.com/redhat/rhel:9.2-489 --remove-signatures --tls-verify=false
```

  11) In the __rhel__ repository in Red Hat Quay, click __Repository tags__, you will find there the two tags corresponding to the previous push command.

  12) Check the __Security scan__ dashboard, this dashboard provides with an easy access to vuelnerabilities found, their severity, and if they are fixed in the next versions.

## __Repository Mirroring__

Red Hat Quay allows to make mirroring from another repositories. Only pull are allowed from mirrored repositories, to push to this repository it will be a _robot account_ who will take this role. 

  1) Click __Create New Repository__, type __mirror-nginx__ as repository name, choose _Private_ as repository visibility and click __Create Private Repository__.

  3) Go to __Settings__, and change _Repository State_ from _normal_ to __mirror__.

  4) As mirroring configuration add the following:
       Registry Location: bitnami/nginx
       Tags: 1.1*,1.20*
       Start Date: Today
       Sync Interval: 10 seconds
       Create robot account with name _quay_workshop_robot_
       Enable mirror

  5) Click __Sync now__. Now in the __Repository Tags__ section you will start to the the new container images added mirrored from _bitnami/nginx_, with the static __Security Scan__ from _Clair_.

## __Installing ACS__

- Click __OperatorHub__ and search for *Advanced Cluster Security* or *ACS*
- Click __install__.
- Take a look to the config shown, use the default namespace *rhacs-operator* to install the RH Quay Operator.
- Click __install__ again.

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

  3) Wait for all the pods in _stackrox_ namespace to become ready and running.

```
oc get pods -n stackrox

NAME                                 READY   STATUS    RESTARTS         AGE
admission-control-6b5dd59bc6-lff89   1/1     Running   0                4h9m
admission-control-6b5dd59bc6-rfdlt   1/1     Running   0                4h9m
admission-control-6b5dd59bc6-xwz4q   1/1     Running   0                4h9m
central-66df9d9c79-2xrvb             1/1     Running   0                24h
central-db-85bb8bfbc5-bzd8n          1/1     Running   0                25h
collector-gsfsk                      3/3     Running   0                4h3m
collector-gvdsw                      3/3     Running   0                4h3m
collector-hdhts                      3/3     Running   0                4h2m
collector-phc6c                      3/3     Running   0                4h3m
collector-x72xg                      3/3     Running   0                4h3m
collector-z7gc5                      3/3     Running   0                4h3m
scanner-58cf565974-mxclc             1/1     Running   1                4h40m
scanner-58cf565974-pcj9k             1/1     Running   0                4h2m
scanner-db-68cccfc7d5-b8zk8          1/1     Running   0                4h40m
sensor-789c5646c7-s5ww2              1/1     Running   0                4h3m
```

  4) Once all the pods are running go to the ACS dashboard.

```
oc get route central -o jsonpath={.spec.host} -n stackrox
```

  5) To access to ACS you will find Admin credential info in the Central instance, use __admin__ as user and go to the _Data_ section in the __central-htpasswd__ secret for the password.

  6) In the ACS dashboard fo to __Platform Configuration__, then __Integrations__ and search for _Authentication Tokens_ at the end of the page. Click __Cluster Init Bundle__.

  7) Click __Generate bundle__, type __my-cluster__ as name, and __Download Kubernetes secrets file__. Apply the secret file downloaded.

```
oc create -f my-cluster-cluster-init-secrets.yaml -n stackrox
```

  8) Last step here is to create a __Secured Cluster__ instance.

#### __NOTE:__ Do not forget to add the port at the end of the _central endpoint_.

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


### __Summary__

Red Hat Quay and ACS instalantion and manage.  

---
### Related Links
[1] [Quay install](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/deploying_the_red_hat_quay_operator_on_openshift_container_platform/operator-preconfigure)

[2] [Repository mirroring](https://access.redhat.com/documentation/en-us/red_hat_quay/3.8/html/manage_red_hat_quay/repo-mirroring-in-red-hat-quay#arch-mirroring-intro)

## Author

Juan Carlos Tovar @RedHat
