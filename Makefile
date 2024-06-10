IMAGE := "pyflink"
TAG := "dev"
SERVICE := "flink"
HELM_REPO := "flink-operator-repo/flink-kubernetes-operator"

cluster:
	@echo "Creating kubernetes cluster and check it ..."
	@kind create cluster --name ${SERVICE} --config kind-cluster.yaml
	@kubectl cluster-info
	@kubectl get nodes -o wide

ns:
	@kubectl create namespace ${SERVICE}
	@kubectl get namespaces
	@kubectl config set-context --current --namespace=flink

install:
	@echo "Fetching flink from Helm chart"
	@helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
	@helm repo update
	@helm search repo flink
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm install prometheus prometheus-community/kube-prometheus-stack
	@echo "Installing certs ..."
	@kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
	@echo "Waiting for 1 min ..."
	@sleep 60
	@echo "Installing flink ..."
	@helm install ${SERVICE} ${HELM_REPO} --namespace ${SERVICE} --debug

build:
	@DOCKER_BUILDKIT=1 docker build -t ${IMAGE}:${TAG} .
	@kind load docker-image ${IMAGE}:${TAG} --name ${SERVICE}

monitor:
	@kubectl apply -f pod-monitor.yaml --namespace ${SERVICE}
	@kubectl port-forward deployment/prometheus-grafana 3000

grafana-creds:
	@kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 --decode ; echo
	@kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

clean:
	@kubectl config delete-cluster kind-${SERVICE}
	@kubectl config delete-context kind-${SERVICE}
	@docker stop $(docker ps -q)
