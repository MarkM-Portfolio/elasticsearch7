# Elasticsearch7 Cluster
Elasticsearch (7.6.1) cluster on top of Kubernetes.
Built from docker image at connections-docker.artifactory.cwp.pnp-hcl.com/elasticsearch7. To provide HTTPS capability, this image integrated SearchGuard. So currently, this image is based on Alpine Linux V3.6 + OpenJDK V1.8 + SearchGuard V7.6.1

### Table of Contents
* [Building ES images](#building-es-images)
* [Environment variables](#environment-variables)
* [Deploy ES Cluster on kubernetes](#deploy-es-on-k8s)
* [Backup & Restore](#backup-restore)
* [Access elasticsearch service](#access-es)
* [Install plug-ins](#plugins)
* [Performance Tuning](#performance-tuning)
* [Troubleshooting](#trouble-shooting)

<a id="building-es-images">

## Building ES images

### Build the cluster ES image

  Currently the cluster image name is also **elasticsearch7**. The pink pipeline tags the image with the repo name by default, and you know, this repo is **elasticsearch7**.

  The Dockerfile is under the root folder and the pipeline will build the image with it, to built it locally, run:
  ```
  $ cd <repo root>
  $ docker build -t connections-docker.artifactory.cwp.pnp-hcl.com/elasticsearch7:latest .
  ```
  Then you can get the image in your local Docker registry. This will be helpful when you want to test your local image change inside Minikube.


<a id="environment-variables">

## Environment variables

This image can be configured by means of environment variables.

|Env|Details|
|---|-------|
|`CLUSTER_NAME`|*e.g. `ICES7`*|
|`NETWORK_HOST`|**|
|`NODE_MASTER`|**|
|`NODE_DATA`|**|
|`NODE_INGEST`|**|
|`HTTP_ENABLE`|**|
|`HTTP_CORS_ENABLE`|**|
|`HTTP_CORS_ALLOW_ORIGIN`|**|
|`NUMBER_OF_MASTERS`|**|
|`MAX_LOCAL_STORAGE_NODES`|**|
|`ES_JAVA_OPTS`|**|


<a id="deploy-es-on-k8s">

## Deploy ES Cluster on kubernetes


### ES Cluster Topology
In a elasticsearch cluster, nodes are defined into three roles. Refer to https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/W28b8df99093e_468e_880f_000d19d33b5c/page/Elasticsearch%20cluster%20for%20docker%20on%20k8s for detailed clarification.

In a formal cluster, we have 3 master + 3 client + 3 data nodes.

### Setup Local ES Cluster with Minikube

The ES Image is integrated with SearchGuard and enabled client side certification. So it's not able to run as single node with Docker. To setup a local development environment, Minikube is necessary:

- Setup Minikube

  Follow the guide to setup Minikube. With Minikube, a single node K8 cluster can be setup on the local machine.
  ```https://github.com/kubernetes/minikube```

  ES Cluster is deployed through **Helm**, so **Helm** is also needed to be installed with K8, see:
  ```https://helm.sh/ ```

- Generate certificates secret and import to Minikube

  ES Cluster needs a set of certs to encrypt the transaction between nodes and between the client. The certs will be imported into K8 secret and mounted into ES container for using later. On Pool Servers, the predefined secret is deployed through other service (PinkServer service or CFC). For local env, it need to be generated, Run:
  ```
  $ cd <repo root>/secret-generator
  $ ./createElasticSearchSecret.sh
  ```
  The script will ask you to input passwords, generate the certs and then automatically import into K8 as a secret named ```elasticsearch-7-secret```

- Create PV/PVC for the data and backup folders
  On Pool Servers, ES PVs/PVCs are deployed through PinkServer service. For local env, we need to create by self. Run
  ```
  $ kubectl create -f <repo root>/util/sample-pv/pv-pvc.yaml
  ```
  It creates PVs (es-pv-backup-7, es-data-7-0, es-data-7-1, es-data-7-2) and PVCs (es-pvc-backup-7, es-pvc-es-data-7-0, es-pvc-es-data-7-1, es-pvc-es-data-7-2) in K8.

- Deploy ES Cluster
  The ES cluster can be deployed through **Helm**, run:
  ```
  $ cd <repo root>/deployment/helm
  $ helm install elasticsearch7 -n elasticsearch7 --set replicaCount=1
  ```
  Helm will deploy a cluster with 1 master / 1 data /1 client nodes on the machine.(Hint: the default setting will eat around 2.5G memory to start up. So you might need to adjust the Minikube VM settings or change the default memory settings inside <repo_root>/deployment/helm/values.yaml)

- Find the cluster's service port
  Run:
  ```
  $ minikube service list
  ```
  Inside the output, you can find elasticsearch7 can be access through ```http://192.168.99.100:30098```.

  **NOTE:** Here we need to use **https** to do the connection instead.

  |  NAMESPACE  |         NAME         |             URL             |
  |-------------|----------------------|-----------------------------|
  | connections | elasticsearch7        | http://192.168.99.100:30098 |
  | connections | es-svc-data          | No node port                |
  | connections | es-svc-master        | No node port                |
  | default     | kubernetes           | No node port                |
  | kube-system | kube-dns             | No node port                |
  | kube-system | kubernetes-dashboard | http://192.168.99.100:30000 |
  | kube-system | tiller-deploy        | No node port                |


- Connect to the cluster through browser.
  You can find the **elasticsearch-metrics.p12** file under ```<repo_root>secret-generator/elasticsearch``` folder, witch is generated by the **createElasticSearchSecret.sh** executed in previous step. Import it as client cert into the browser. Then you can use ```http://192.168.99.100:30098``` to connect the cluster inside your browser.

### Deploy ES Cluster on Pool Server

- This is similar but simpler than local Minikube env setup. The secret and the PV/PVC have been deployed through other services (PinkServer or CFC). We just need to deploy the ES Cluster itself. Run:
  ```
  $ helm install elasticsearch7 -n elasticsearch7 --set replicaCount=1
  ```
  All set.


<a id="backup-restore">

## Backup & Restore

Admin may need to contact __metrics__ team for the __reponame__.

### Registry snapshot repository

Before any snapshot or restore operation can be performed, a repository should be registered in Elasticsearch.
```

# sendRequest.sh is a util(in probe/) so that we can interact with es like what official site suggested.   

Connect to an elasticsearch7 client pod by run command attached below:    

kubectl exec -ti -n connections $(kubectl get pods -n connections  -o wide -a |grep es-client-7 |awk '{print $1}' |head -n 1) -- bash

echo "----------------to create repo"
./sendRequest.sh PUT /_snapshot/<REPONAME> \
  -H 'Content-Type: application/json' \
  -d '{"type": "fs","settings": {"compress" : true, "location": "<BACKUPPATH>"}}'

echo "----------------to check created repo"
./sendRequest.sh GET /_snapshot/_all?pretty

You should see output list below :
{ "<REPONAME>" : { "type" : "fs", "settings" : { "compress" : "true", "location" : "<BACKUPPATH>" } } }
```
You need an env which can access to Kubernetes env which hosted the Elasticsearch cluster to perform backup/restore steps.

### Backup snapshot

We have 2 methods available to do backup, and actually they all do the same thing(to run a backup script in a pod).

- PS: admin can modify probe/doBackup.sh to customize the snapshot name.

#### Method 1 __(Recommended)__ : run backup job to execute the backup script.

Make sure you know the REPONAME and BACKUPPATH value for the repository that your want to register and backup.   

PS: admin need to modify job_backup.yaml to set the reponame like below :   
At line 13 :
```
			"status_text=$(/opt/elasticsearch-7.6.1/probe/doBackup.sh <REPONAME>);
```
Start the backup operation by run command :   
`kubectl create -f <your yaml file path>/job_backup.yaml`

Then a job will be created, which will create a pod to run backup script.   

Run following command to check the backup pod status to ensure it completed the backup process.
```
kubectl get pods -n connections -a |grep job-backup
job-backup-7-nwdqw             0/1       Completed   0          13h
```

The pod will remain in a status of completed/Terminated so that admin can see logs during backup by run command attached below:

```
kubectl logs -n connections $(kubectl get pods -n connections  -o wide -a |grep job-backup-7 |awk '{print $1}')

The log should include response text like below.
{"snapshot":{"snapshot":"snapshot20171127072737","uuid":"TK9Xv6rCRIywIu5ExFeWww","version_id":5050199,"version":"7.6.1","indices":[".kibana","twitter","firstindex"],"state":"SUCCESS","start_time":"2017-11-27T07:27:37.970Z","start_time_in_millis":1511767657970,"end_time":"2017-11-27T07:27:40.287Z","end_time_in_millis":1511767660287,"duration_in_millis":2317,"failures":[],"shards":{"total":11,"failed":0,"successful":11}}}
```

And Since both the job and pod are not deleted after backup, the next time to do backup:

```
sudo kubectl delete -f <Your script path>/job_backup.yaml
sudo kubectl create -f <Your script path>/job_backup.yaml
```


#### Method 2: run backup script after exec into one of es pod(recommend the client one ).

```
  kubectl exec -n connections -it $(kubectl get pods -n connections  |grep -m 1 es-client-7 |awk '{print $1}') /bin/bash <<EOF
    probe/doBackup.sh changeThisToRepoName
  EOF

```

### Restore snapshot

We have 2 methods available to do restore, and actually they all do the same thing(to run a restore script in a pod).

Before restore, admin can check the list of all snapshots.

```
  ./sendRequest.sh get /_snapshot/<REPONAME>/_all?pretty

```
Make sure you know the REPONAME and SNAPSHOTNAME value for the snapshot that your want to restore from.

#### Method 1 (__(Recommended)__): run restore job to execute the restore script.

PS: admin need to modify \<your yaml file path\>/job_restore.yaml to set the repoName and snapshootName

At line 13 :    
```
	"status_text=$(/opt/elasticsearch-7.6.1/probe/doRestore.sh <REPONAME> <SNAPSHOTNAME>);
```
Start the restore operation by run command :   

`kubectl create -f <your yaml file path>/job_restore.yaml`

Then a job will be created, which will create a pod to run restore script.

```
kubectl get pods -n connections -a |grep job-restore
job-restore-7-6128f            0/1       Completed   0          12h
```

The pod will remain in a status of completed/Terminated so that admin can see logs by run command attached below:

```
kubectl logs -n connections $(kubectl get pods -n connections  -o wide -a |grep job-restore-7 |awk '{print $1}')

The log should include response text like below.
'{"snapshot":{"snapshot":"snapshot20171023075758","indices":["indexname"],"shards":{"total":5,"failed":0,"successful":5}}}'
```

And Since both the job and pod are not deleted after restore, the next time to do restore:

```
sudo kubectl delete -f <Your yaml file path>/job_restore.yaml
sudo kubectl create -f <Your yaml file path>/job_restore.yaml
```


#### Method 2: run restore script after exec into one of es pod(recommend the client one ).

```
  kubectl exec -n connections -it $(kubectl get pods -n connections  |grep -m 1 es-client-7 |awk '{print $1}') /bin/bash <<EOF
    probe/doRestore.sh changeThisToRepoName changeThisToSnapshotName
  EOF

```

<a id="access-es">

## Access elasticsearch service

### Get the es node ip & port
```
$ kubectl get svc -l component=elasticsearch,role=client -n connections
NAME            CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
elasticsearch7   10.108.98.63   <pending>     9200:30098/TCP   10m
```
### View elasticsearch cluster information

```
$ curl http://`hostname -i`:30098
{
  "name" : "es-client-7-2673017220-1fp5m",
  "cluster_name" : "ICES7",
  "cluster_uuid" : "bJHWubd9T7-58N95R8zIPA",
  "version" : {
    "number" : "7.6.1",
    "build_hash" : "2cfe0df",
    "build_date" : "2017-05-29T16:05:51.443Z",
    "build_snapshot" : false,
    "lucene_version" : "6.5.1"
  },
  "tagline" : "You Know, for Search"
}
```

### Check elasticsearch health.
See `PORT(S)` of elasticsearch7 for `elasticsearch7` service port in host.

```
$ curl http://`hostname -i`:30098/_cluster/health?pretty
{
  "cluster_name" : "ICES7",
  "status" : "red",
  "timed_out" : false,
  "number_of_nodes" : 7,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 10,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 0.0
}

```

### Check elasticsearch7 cluster state.
```
$ curl http://`hostname -i`:30098/_cluster/state?pretty
{
  "cluster_name" : "ICES7",
  "version" : 21,
  "state_uuid" : "TVf3Wx4kRD-uQn-q6imnKw",
  "master_node" : "8kQURxjpT4O_2RCPsbUN8A",
  "blocks" : { },
  "nodes" : {
    "X1kzAsrmT1K6j8ETa1drAA" : {
      "name" : "es-client-7-2673017220-5dkrk",
      "ephemeral_id" : "rPzpxw-5TBa04MBYOhtBbA",
      "transport_address" : "10.32.0.52:9300",
      "attributes" : { }
    },
    "_Y-jVIw5RIi_jxyMuMVoAw" : {
      "name" : "es-data-7-0",
      "ephemeral_id" : "fWIIa0EaRqyluc3JwjS50g",
      "transport_address" : "10.32.0.49:9300",
      "attributes" : { }
    },
    ......

```

<a id="plugins">

## Install plug-ins

The image used in this repo is very minimalist. However, one can install additional plug-ins at will by simply specifying the `ES_PLUGINS_INSTALL` environment variable in the desired pod descriptors. For instance, to install Google Cloud Storage and X-Pack plug-ins it would be like follows:
```
- name: "ES_PLUGINS_INSTALL"
  value: "repository-gcs,x-pack"
```

<a id="performance-tuning">

## Performance Tuning

### Disable memory swappiness

Memory swapping is very bad for elasticsearch7 server performance, so it is recommended to disable memory swap in cluster. ES Cluster supports enabling it through helm config inside **deployment/helm/elasticsearch7/values.yaml**

```
common.env.MEMORY_LOCK=true
```

Currently the default value is 'false' and the swapping is kept as enabled. Because some external discussions shows memory swapping is not that useful in Kubernetes environment. This part needs further investigation.

Find more details in below wiki page:
https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/W28b8df99093e_468e_880f_000d19d33b5c/page/Elasticsearch%20-%20Performance


### Pod Resource Limitation

Update in es-3-ss-master.yaml, es-5-ss-data.yaml, es-6-client.yaml.
Assign more cpu & memory according to your system resource. It'd be better to set requests.cpu & request.memory to the same value with limits.cpu & limits.memory.

```
resources:
  limits:
    cpu: "2"
    memory: "8Gi"
  requests:
    cpu: "1"
    memory: "8Gi"
```

### ES memory

Update in es-3-ss-master.yaml, es-5-ss-data.yaml, es-6-client.yaml.

It'd better to set the `-Xms` and `-Xmx` to the same value that is half of pod's limits.memory, but no more than 32G.
```
- name: "ES_JAVA_OPTS"
  value: "-Xms4g -Xmx4g"
```

<a id="trouble-shooting">

## Trouble Shooting

- Available is 0 & Status is ImagePullBackOff

```
$ kubectl get deployment,pods -l component=elasticsearch7 -n connections
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/es-client-7   1/1     1            1           3h36m

NAME                              READY   STATUS    RESTARTS   AGE
pod/es-client-7-bc6c49d98-hwwck   1/1     Running   0          3h36m
pod/es-data-7-0                   1/1     Running   0          3h36m
pod/es-master-7-0                 1/1     Running   0          3h36m
```

Can't pull image from artifactory. Check pod details to identify as below:
```
$ kubectl describe po es-client-7-bc6c49d98-hwwck -n connections

......

Events:
  FirstSeen	LastSeen	Count	From					SubObjectPath			Type		Reason		Message
  ---------	--------	-----	----					-------------			--------	------		-------
  21m		21m		1	default-scheduler							Normal		Scheduled	Successfully assigned es-client-3870162725-2ft2g to lcauto24.swg.usma.ibm.com
  20m		20m		1	kubelet, lcauto24.swg.usma.ibm.com	spec.initContainers{sysctl}	Normal		Pulled		Container image "busybox" already present on machine
  20m		20m		1	kubelet, lcauto24.swg.usma.ibm.com	spec.initContainers{sysctl}	Normal		Created		Created container with id 3274d7e2c4f9071d2f3173543da80f4b7613b2d29bd66e1d202e0a1580f6162d
  20m		20m		1	kubelet, lcauto24.swg.usma.ibm.com	spec.initContainers{sysctl}	Normal		Started		Started container with id 3274d7e2c4f9071d2f3173543da80f4b7613b2d29bd66e1d202e0a1580f6162d
  20m		3m		8	kubelet, lcauto24.swg.usma.ibm.com	spec.containers{es-client}	Normal		Pulling		pulling image "artifactory.swg.usma.ibm.com:6562/elasticsearch-cluster:latest"
  20m		3m		8	kubelet, lcauto24.swg.usma.ibm.com	spec.containers{es-client}	Warning		Failed		Failed to pull image "artifactory.swg.usma.ibm.com:6562/elasticsearch-cluster:latest": rpc error: code = 2 desc = Error: Status 400 trying to pull repository elasticsearch-cluster: "{\n  \"errors\" : [ {\n    \"status\" : 400,\n    \"message\" : \"Unsupported docker v1 repository request for 'connections-docker'\"\n  } ]\n}"
  20m		3m		8	kubelet, lcauto24.swg.usma.ibm.com					Warning		FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "es-client" with ErrImagePull: "rpc error: code = 2 desc = Error: Status 400 trying to pull repository elasticsearch-cluster: \"{\\n  \\\"errors\\\" : [ {\\n    \\\"status\\\" : 400,\\n    \\\"message\\\" : \\\"Unsupported docker v1 repository request for 'connections-docker'\\\"\\n  } ]\\n}\""

  20m	16s	39	kubelet, lcauto24.swg.usma.ibm.com	spec.containers{es-client}	Normal	BackOff		Back-off pulling image "artifactory.swg.usma.ibm.com:6562/elasticsearch-cluster:latest"
  20m	16s	39	kubelet, lcauto24.swg.usma.ibm.com					Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "es-client" with ImagePullBackOff: "Back-off pulling image \"artifactory.swg.usma.ibm.com:6562/elasticsearch-cluster:latest\""
  ```

  Action: Contact system admin to check if the icdeploy@us.ibm.com account in myregkey has trouble on pulling image from artifactory

## Security Design
ElasticSearch does not provide Authentication by itself, we choose to integrate **SearchGuard** to provide HTTPS + client cert access. The node-node & node-client transactions are both encrypted and two-way trusted. Details design can be found at:
https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/W28b8df99093e_468e_880f_000d19d33b5c/page/Elasticsearch%20-%20Security%20Design
