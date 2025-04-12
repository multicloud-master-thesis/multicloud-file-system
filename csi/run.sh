kind delete cluster --name multicloud
kind create cluster --config kind-config.yaml --name multicloud
kind load docker-image multicloud-csi-driver:0.1.0 --name multicloud
kubectl apply -f deploy/namespace.yaml
kubectl apply -f deploy/csi-driver.yaml
kubectl apply -f deploy/rbac.yaml
kubectl apply -f deploy/controller.yaml
kubectl apply -f deploy/node.yaml
kubectl apply -f deploy/storageclass.yaml
kubectl apply -f deploy/testpod.yaml