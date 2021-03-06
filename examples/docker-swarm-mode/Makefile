setup-clean:
	docker-machine rm -f registry splunk1 splunk2 splunk3

setup:
	docker-machine create \
		--driver=virtualbox \
		--virtualbox-disk-size=200000 \
		--virtualbox-memory=512 \
		--virtualbox-cpu-count=1 \
		--engine-install-url=https://test.docker.com \
		registry
	eval $$(docker-machine env registry) && docker run \
		--name registry \
		--publish 80:5000/tcp \
		-d registry:2
	docker-machine create \
		--driver=virtualbox \
		--virtualbox-disk-size=200000 \
		--virtualbox-memory=4096 \
		--virtualbox-cpu-count=2 \
		--engine-install-url=https://test.docker.com \
		--engine-insecure-registry $$(docker-machine ip registry) \
		splunk1
	docker-machine create \
		--driver=virtualbox \
		--virtualbox-disk-size=200000 \
		--virtualbox-memory=3072 \
		--virtualbox-cpu-count=2 \
		--engine-install-url=https://test.docker.com \
		--engine-insecure-registry $$(docker-machine ip registry) \
		splunk2
	docker-machine create \
		--driver=virtualbox \
		--virtualbox-disk-size=200000 \
		--virtualbox-memory=3072 \
		--virtualbox-cpu-count=2 \
		--engine-install-url=https://test.docker.com \
		--engine-insecure-registry $$(docker-machine ip registry) \
		splunk3
	eval $$(docker-machine env splunk1) && docker swarm init --listen-addr $$(docker-machine ip splunk1) --secret splunk_swarm_cluster
	@echo "Do (with --ca-hash from above): "
	@echo "eval $$(docker-machine env splunk2) && docker swarm join --listen-addr $$(docker-machine ip splunk2) --secret splunk_swarm_cluster --ca-hash HASH_HERE $$(docker-machine ip splunk1):2377" 
	@echo "eval $$(docker-machine env splunk3) && docker swarm join --listen-addr $$(docker-machine ip splunk3) --secret splunk_swarm_cluster --ca-hash HASH_HERE $$(docker-machine ip splunk1):2377"
	@echo "eval $$(docker-machine env splunk1) && docker network create --driver=overlay splunk"

build:
	cd ./../../images/splunk && docker build -t $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2 . && docker push $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2
	cd ./../../images/lb && docker build -t $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-lb . && docker push $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-lb
	cd ./../../images/consul && docker build -t $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-consul . && docker push $$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-consul

deploy-consul:
	docker service create \
		--mode replicated \
		--replicas 3 \
		--reserve-memory 128m \
		--name consul \
		--mode replicated \
		--label splunk.cluster=consul \
		--network splunk \
		--env CONSUL_DATA_DIR="/consul/data" \
		--env CONSUL_DC="dc" \
		--env CONSUL_DOMAIN="splunk" \
		--env CONSUL_CLIENT="0.0.0.0" \
		--env CONSUL_BOOTSTRAP_EXPECT="3" \
		--env CONSUL_JOIN="consul" \
		--env CONSUL_ADVERTISE_INTERFACE=eth2 \
		--publish 8500:8500 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-consul

deploy-license-master:
	docker service create \
		--constraint "node.role == manager" \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 512m \
		--name license-master \
		--label splunk.cluster=license-master \
		--network splunk \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=license_master \
		--env INIT_GENERAL_PASS_4_SYMM_KEY=general-changeme \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env INIT_WEB_ENABLED=true \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2
	docker cp *.lic $$(docker ps -qa --filter=label=splunk.cluster=license-master):/opt/splunk-deployment/licenses

deploy-cluster-master:
	docker service create \
		--constraint "node.role == manager" \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 512m \
		--name cluster-master \
		--label splunk.cluster=cluster-master \
		--network splunk \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=cluster_master,license_slave \
		--env INIT_CLUSTERING_PASS_4_SYMM_KEY=clustering-changeme \
		--env INIT_CLUSTERING_REPLICATION_FACTOR=1 \
		--env INIT_CLUSTERING_SEARCH_FACTOR=1 \
		--env INIT_CLUSTERING_CLUSTER_LABEL=cluster1 \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env INIT_GENERAL_PASS_4_SYMM_KEY=general-changeme \
		--env INIT_LICENSE_MASTER=https://license-master:8089 \
		--env INIT_WEB_ENABLED=true \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-shc-deployer:
	docker service create \
		--constraint "node.role == manager" \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 512m \
		--name shc-deployer \
		--label splunk.cluster=shc-deployer \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=shc-deployer \
		--env INIT_SHCLUSTERING_PASS_4_SYMM_KEY=shclustering-changeme \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-shc-member:
	docker service create \
		--mode replicated \
		--replicas 3 \
		--reserve-memory 1024m \
		--name shc-member \
		--label splunk.cluster=shc-member \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=shc_member,shc_deployer_client,license_slave,cluster_searchhead \
		--env INIT_SHCLUSTERING_PASS_4_SYMM_KEY=shclustering-changeme \
		--env INIT_SHCLUSTERING_SHCDEPLOYER=https://shc-deployer:8089 \
		--env INIT_SHCLUSTERING_REPLICATION_FACTOR=3 \
		--env INIT_SHCLUSTERING_SHCLUSTER_LABEL=shcluster1 \
		--env INIT_GENERAL_PASS_4_SYMM_KEY=general-changeme \
		--env INIT_LICENSE_MASTER=https://license-master:8089 \
		--env INIT_CLUSTERING_PASS_4_SYMM_KEY=clustering-changeme \
		--env INIT_CLUSTERING_CLUSTER_MASTER=https://cluster-master:8089 \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env INIT_SHCLUSTER_AUTOBOOTSTRAP=3 \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-cluster-slave:
	docker service create \
		--mode replicated \
		--replicas 4 \
		--reserve-memory 1024m \
		--name cluster-slave \
		--label splunk.cluster=cluster-slave \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=cluster_slave,license_slave \
		--env INIT_GENERAL_PASS_4_SYMM_KEY=general-changeme \
		--env INIT_LICENSE_MASTER=https://license-master:8089 \
		--env INIT_CLUSTERING_PASS_4_SYMM_KEY=clustering-changeme \
		--env INIT_CLUSTERING_CLUSTER_MASTER=https://cluster-master:8089 \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-dmc:
	docker service create \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 1024m \
		--name dmc \
		--label splunk.cluster=dmc \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=license_slave,cluster_searchhead,dmc \
		--env INIT_CLUSTERING_PASS_4_SYMM_KEY=clustering-changeme \
		--env INIT_CLUSTERING_CLUSTER_MASTER=https://cluster-master:8089 \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env INIT_GENERAL_PASS_4_SYMM_KEY=general-changeme \
		--env INIT_LICENSE_MASTER=https://license-master:8089 \
		--env INIT_KVSTORE_ENABLED=false \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-hw-forwarder:
	docker service create \
		--constraint "node.role == manager" \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 256m \
		--name dmc \
		--label splunk.cluster=hw-forwarder \
		--env SPLUNK_START_ARGS=--accept-license \
		--env SPLUNK_ROLES=hw_forwarder \
		--env INIT_INDEX_DISCOVERY_PASS_4_SYMM_KEY=indexdiscovery-changeme \
		--env INIT_INDEX_DISCOVERY_MASTER_URI=https://cluster-master:8089 \
		--env INIT_ADD_UDP_PORT=1514 \
		--env CONSUL_HOST=consul \
		--env CONSUL_DC=dc \
		--env CONSUL_DOMAIN=splunk \
		--env CONSUL_ADVERTISE_INTERFACE=eth1 \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2

deploy-lb:
	docker service create \
		--constraint "node.role == manager" \
		--mode replicated \
		--replicas 1 \
		--reserve-memory 256m \
		--name lb \
		--mode replicated \
		--label splunk.cluster=lb \
		--network splunk \
		--publish 8000:8000 \
		--publish 8100:8100 \
		--publish 8200:8200 \
		--publish 8500:8500 \
		--env CONSUL_DC="dc" \
		--env CONSUL_HOST="consul:8500" \
		--env CONSUL_DOMAIN="splunk" \
		$$(docker-machine ip registry)/outcoldman/splunk-cluster:6.4.2-lb

deploy: deploy-consul deploy-license-master deploy-cluster-master deploy-shc-deployer deploy-shc-member deploy-cluster-slave deploy-dmc deploy-hw-forwarder deploy-lb

clean:
	docker service rm consul license-master cluster-master shc-deployer shc-member cluster-slave dmc hw-forwarder lb

