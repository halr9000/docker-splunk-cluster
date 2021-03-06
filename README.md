# Table of Contents

- [Introduction](#introduction)
    - [Version](#version)
- [How it works](#how-it-works)
    - [Cluster-aware image](#cluster-aware-image)
        - [Configuration](#configuration)
            - [License Master](#license-master)
            - [License Slave](#license-slave)
            - [Cluster Master](#cluster-master)
            - [Cluster Search Head](#cluster-search-head)
            - [Cluster Slave](#cluster-slave)
            - [SHC Deployer](#shc-deployer)
            - [SHC Member](#shc-member)
            - [SHC Deployer Client](#shc-deployer-client)
            - [HW Forwarder](#hw-forwarder)
            - [DMC](#dmc)
        - [Files listing in image](#files-listing-in-image)
            - `/`
            - `/deployment`
    - [Load balancing image](#load-balancing-image)
    - [Consul image](#consul-image)
- [Use it](#use-it)
    - [Deploy](#deploy)
        - [On docker instance](#on-docker-instance)
            - [If you do not have a License](#if-you-do-not-have-a-license)
            - [If you have a Splunk Enterprise License](#if-you-have-a-splunk-enterprise-license)
        - [On docker swarm](#on-docker-swarm)
        - [On kubernetes](#on-kubernetes)
    - [Examples after setup](#examples-after-setup)
        - [Install application on SHC using SHC Deployer](#install-application-on-shc-using-shc-deployer)
- [TODO](#todo)


## Introduction

> NOTE: I'm working at Splunk, but this is not an official Splunk images.
> I build them in my free time when I'm not at work. I have some knowledge
> about Splunk, but you should think twice before putting them in
> production. I run these images on my own home server just for
> my personal needs. If you have any issues - feel free to open a
> [bug](https://github.com/outcoldman/docker-splunk-cluster/issues).

> Use for learning purposes.

This repository contains set of examples how to run Splunk Enterprise cluster in Docker,
including Search Head Cluster and Indexing Cluster.

The main purpose of this repository is to show how to automate Splunk Cluster deployment.
Below you can find examples how to setup Cluster on Docker, Swarm Mode (1.12-rc4 has issues), Kubernetes (TODO).

### Version

Based on `outcoldman/splunk:6.4.2`.

* Version: `6.4.2`
* Build: `00f5bb3fa822`

## How it works

### Cluster-aware image

These examples depend on the custom image, which you can build using `./images/splunk` folder.
This image is based on `outcoldman/splunk` and includes several changes:

- Adds consul binary to the image. We use consul for service discovery.
- Adds Splunk `splunkcluster` index, which will be used to send here all internal
    logs about the cluster from `consul` and `load balancer`.
- Adds deployment python scripts to `/opt/splunk-deployment`, which are executed
    only on first start by using `SPLUNK_CMD` as `cmd python /opt/splunk-deployment/init.py`.
- Register `consul` as scripted input, so it always will be launched with `splunkd`.
    All logs from `consul` go to the `splunkcluster` index.

> NOTE: do not override `SPLUNK_CMD` when you start this image, this will disable
cluster initialization.

#### Configuration

- `SPLUNK_ROLES` define the roles for the container. Use comma to define multiple roles (which are compatible).
    - `license_master`
    - `license_slave`
    - `cluster_master`
    - `cluster_searchhead`
    - `cluster_slave`
    - `shc_deployer`
    - `shc_member`
    - `shc_deployer_client`
    - `hw_forwarder`

- `INIT_KVSTORE_ENABLED` - force to enable/disable KVStore.
- `INIT_WEB_ENABLED` - force to enable/disable Web.
- `INIT_INDEXING_ENABLED` - force to enable/disable Indexing.
- `INIT_DMC` - force to enable/disable DMC app.
- `INIT_WEB_SETTINGS_PREFIX` - set prefix for Web.
- `INIT_INDEX_DISCOVERY_MASTER_URI` - sets uri to Cluster Master with enabled Index Discovery. When indexing is off. Defaults to `https://cluster-master:8089`.
- `INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY` - set index discovery `pass4SymmKey`. When indexing is off. Defaults to `indexdiscovery-changeme`.

Consul related variables

- `CONSUL_HOST` - which consul host to join. Defaults to `consul`.
- `CONSUL_ADVERTISE_INTERFACE` - which interface IP to use for advertising.
- `CONSUL_DC` - name of data center. Defaults to `dc`.
- `CONSUL_DOMAIN` - consul default domain. Defaults to `splunk`.

##### License Master

- Add licenses to the pool if it will find any `*.lic` files under `/opt/splunk-deployment/`.
- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_GENERAL_PASS_4_SYMM_KEY` - set `pass4SymmKey` for the License Cluster. Defaults to `general-changeme`.
- `INIT_WAIT_LICENSE` - wait for license files under `/opt/splunk-deployment/licenses`. Defaults to `False`.

##### License Slave

- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_GENERAL_PASS_4_SYMM_KEY` - set `pass4SymmKey` for the License Cluster. Defaults to `general-changeme`.
- `INIT_LICENSE_MASTER` - uri to License Master. Defaults to `https://license-master:8089`.


##### Cluster Master

- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- Sets `repFactor = auto` for all default indexes. This configuration will be deployed to indexers using `master-apps` folder.
- Sets up index discovery.
- Sets clustering `mode = master`.

- `INIT_CLUSTERING_PASS_4_SYMM_KEY` - set `pass4SymmKey` for Indexing Cluster. Defaults to `clustering-changeme`.
- `INIT_CLUSTERING_REPLICATION_FACTOR` - set replication factor. Defaults to `1`.
- `INIT_CLUSTERING_SEARCH_FACTOR` - set search factor. Defaults to `1`.
- `INIT_CLUSTERING_CLUSTER_LABEL` - set cluster label. Defaults to `cluster`.
- `INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY` - set index discovery `pass4SymmKey`. Defaults to "indexdiscovery-changeme".

##### Cluster Search Head

- Require KVStore.
- Require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- Sets clustering `mode = searchhead`.

- `INIT_CLUSTERING_PASS_4_SYMM_KEY` - set `pass4SymmKey` for Indexing Cluster. Defaults to `clustering-changeme`.
- `INIT_CLUSTERING_CLUSTER_MASTER` - set cluster master uri. Defaults to `https://cluster-master:8089`.

Before starting Splunk after applying configuration changes waits for the `cluster_master` 
role in cluster master defined with `INIT_CLUSTERING_CLUSTER_MASTER`.

##### Cluster Slave

- Does not require KVStore.
- Does not require Splunk Web.
- Require Indexing.
- Does not require DMC app.

- Sets clustering `mode = slave`.
- Enables listening on `9997` for forwarded data.

- `INIT_CLUSTERING_PASS_4_SYMM_KEY` - set `pass4SymmKey` for Indexing Cluster. Defaults to `clustering-changeme`.
- `INIT_CLUSTERING_CLUSTER_MASTER` - set cluster master uri. Defaults to `https://cluster-master:8089`.

Before starting Splunk after applying configuration changes waits for the `cluster_master` 
role in cluster master defined with `INIT_CLUSTERING_CLUSTER_MASTER`.

##### SHC Deployer

- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_SHCLUSTERING_PASS_4_SYMM_KEY` - set `pass4SymmKey` for Search Head Cluster. Defaults to `shclustering-changeme`.

##### SHC Member

- Require KVStore.
- Require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_SHCLUSTERING_PASS_4_SYMM_KEY` - set `pass4SymmKey` for Search Head Cluster. Defaults to `shclustering-changeme`.
- `INIT_SHCLUSTERING_MGMT_URI` - set management uri of current server. Defaults to `https://$HOSTNAME:8089`.
- `INIT_SHCLUSTERING_REPLICATION_FACTOR` - set replication factor. Defaults to `3`.
- `INIT_SHCLUSTERING_SHCLUSTER_LABEL` - set Search Head Cluster label. Defaults to `shcluster`.
- `INIT_SHCLUSTER_AUTOBOOTSTRAP` - auto bootstrap Search Head Cluster on this number of members. Defaults to `3`.

After start this role also is trying to auto bootstrap Search Head Cluster or add itself
to existing Search Head Cluster. Using consul every SHC Member elects itself as a Consul Leader on the Consul Service
(not related to Search Head Cluster Captain), adds itself to the list of SHC Members. Checks the current list, if 
number of members is less than `INIT_SHCLUSTER_AUTOBOOTSTRAP` - just release leadership on Consul Service. If equal to -
does bootstrapping of SHC, if larger - adds itself to Search Head Cluster.

##### SHC Deployer Client

- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_SHCLUSTERING_SHCDEPLOYER` - set uri to Search Head Cluster deployer. Defaults to `https://shc-deployer:8089`.

Before starting Splunk after applying configuration changes waits for the
Search Head Cluster Deployer defined with `INIT_SHCLUSTERING_SHCDEPLOYER`.

##### HW Forwarder

- Does not require KVStore.
- Does not require Splunk Web.
- Does not require Indexing.
- Does not require DMC app.

- `INIT_ADD_UDP_PORT` - add listening on port defined with this variable, sets `connection_host = dns`,
    `index = splunkcluster` and register this as a service in consul with name `syslog`.

##### DMC

- Does not require KVStore.
- Require Splunk Web.
- Does not require Indexing.
- Require DMC app.

> TODO: dashboards are not configured

#### Files listing in image

##### /

- `consul.sh` - script for scripted input, rule how we launch `consul`. Important, that
    we persist consul data in `"$SPLUNK_HOME/var/consul"`.
- `consul_check.sh` - check script used by consul to verify that `splunkd` is alive.
- `indexes.conf` - define `splunkcluster` index, which will be used to send logs from
    `consul` and `load balancer`.
- `inputs.conf` - definition of scripted input, which will allow us to launch `consul`
    with `splunkd`.

##### /deployment

- `init.py` - startup script, which will be used to initialize the cluster. Invoked with
    cmd python /opt/splunk-deployment/init.py`.
- `init_consul.py` - helper functions to work with local consul.
- `init_helpers.py` - helper functions.
- `init_<role>.py` - rules how to initialize the role.
- `_disable_<what>/` - set of default configuration files which allow to disable
    this feature. For example `_disable_indexing` contains configuration files to
    forward events to the indexing cluster using index discovery.
- `<ROLE>` - set of configurations rules which will be applied to defined role.

### Load balancing image

Folder `lb` is building HTTP load balancing image. It is based on `consul`, `consul-template`
and `haproxy`. `consul-template` listen for services updates in the consul and
regenerates the `haproxy` configuration.

Ports:

- `8000` - load balances between SHC servers, using cookie `SERVERID`.
- `8100` - redirects to Cluster Master.
- `8200` - redirects to DMC.
- `8300` - redirects to License Master.
- `8500` - redirects to consul.

> NOTE: consul is not secured by default.

### Consul image

Image based on `consul:v0.6.4`.

## Use it

### Deploy

#### On docker instance

> NOTE2: If you are using Docker for Mac - it allocates just 2Gb by default, not enough for this demo. Set more. Maybe 8Gb.

```
cd ./examples/docker
```

This folder has two docker-compose files. One which does not require License Master and Splunk Enterprise License
`docker-compose.yml` and second is an extension for the first one, which adds License Master node. `Makefile` in this folder
deals with how `docker-compose` needs to be invoked.

##### If you do not have a License

Build images.

```
make build
```

Deploy instances.

```
make deploy
```

Watch for status of deployment:
- Open `http://<docker>:8500` to watch for all green services and hosts.
- Watch for `docker-compose logs -f shc-member` for the line `Successfully bootstrapped this node as the captain with the given servers.`.
    This will mean that SHC is bootstrapped.
- Open Cluster Master web on `http://<docker>:8100` and check `Indexer Clustering: Master Node` page
    that Indexes are replicated and ready for search.
- Open SHC on `http://<docker>:8000` and check that you see logs from all instances `index="_internal" | stats count by host`.

You can scale up later with

```
docker-compose -f docker-compose.yml scale cluster-slave=8 shc-member=5
```

To clean use

```
make clean
```

##### If you have a Splunk Enterprise License

If you have Splunk Enterprise License copy it in this folder (make sure that license files have extension `*.lic`).

Build images.

```
make build-lm
```

Deploy instances. This command copies license files to the license master node, deploys 3 SHC Members and 4 Indexer Cluster Slaves.
Command will fail if you don't have license files in current folder.

```
make deploy-lm
```

Watch for status of deployment:
- Open `http://<docker>:8500` to watch for all green services and hosts.
- Watch for `docker-compose logs -f shc-member` for the line `Successfully bootstrapped this node as the captain with the given servers.`.
    This will mean that SHC is bootstrapped.
- Open Cluster Master web on `http://<docker>:8100` and check `Indexer Clustering: Master Node` page
    that Indexes are replicated and ready for search.
- Open SHC on `http://<docker>:8000` and check that you see logs from all instances `index="_internal" | stats count by host`.

You can scale up later with

```
docker-compose -f docker-compose.yml -f docker-compose.license-master.yml scale cluster-slave=8 shc-member=5
```

To clean use

```
make clean-lm
```

#### On docker swarm

> In progress
> TODO: seems like docker swarm mode in 1.12-rc4 has issue with network discovery. So example does not work.
> NOTE: Splunk Enterprise License is required

```
cd ./examples/docker-swarm-mode
```

Copy Splunk Enterprise license (if you have) in this folder (make sure that license files have extension `*.lic`).

Prepare swarm. This command will create 4 docker-machine instances in VirtualBox.
One instance is a docker registry. Another 3 will be part of Swarm cluster.

```
make setup
```

Do all steps from echoed from command above (two nodes need to join swarm cluster and create a network).

Build images. This command will build images and publish to local registry.

```
make build
```

Deploy cluster.

```
make deploy
```

To clean splunk cluster use

```
make clean
```

To kill all docker machines use

```
make setup-clean
```

#### On kubernetes

> TODO

### Examples after setup

#### Install application on SHC using SHC Deployer

```
docker cp ~/Downloads/splunk_app_aws shc-deployer:/opt/splunk/etc/shcluster/apps/
docker exec shc-deployer entrypoint.sh chown -R splunk:splunk /opt/splunk/etc/shcluster/apps/
docker exec shc-deployer entrypoint.sh splunk apply shcluster-bundle -restart true --answer-yes -target https://$(docker ps --filter=label=splunk.cluster=shc-member -q | head -1):8089 -auth admin:changeme
```

## TODO:

- [ ] Secret storage for getting secrets (currently everything is in plain text from env variables). Might use Vault from HashiCorp.
- [ ] DMC Server (with all configurations setup automatically)
- [ ] Deployment Server
- [ ] Forwarders
- [ ] Encrypt consul communication
- [ ] CA Authority. Do not skip certificate verification.
- [ ] Check if there are better way to configure SSO (including trustedIP)
- [ ] On SHC we should log IP addresses with "tools.proxy.on = True"
- [ ] Collecting logs from consul server
- [ ] Upgrade to consul-template 0.16.0 rtm.
- [ ] Secure by default `8500`.
- [ ] Use `socket` to get fqdn.
- [ ] SHC Autobootstrap should support removed members.
- [ ] Make all consul requests with retry.
- [ ] Possible issues with permissions.
