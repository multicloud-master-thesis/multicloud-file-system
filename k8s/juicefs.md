# JuiceFS CSI Driver setup with example deployment

Create kind cluster

```bash
    kind create cluster
```

Create a namespace for JuiceFS

```bash
    kubectl create namespace juicefs-system
```

Install the JuiceFS CSI driver via Helm

```bash
    helm repo add juicefs https://juicedata.github.io/charts/
    helm repo update
    helm install juicefs-csi-driver juicefs/juicefs-csi-driver -n juicefs-system
```

Create a JuiceFS filesystem

```bash
    kubectl apply -f juice-fs.yaml
```

Verify it is working

Check if pods are running
```bash
    kubectl get pods
```

Create a file from app1

```bash
    kubectl exec $(kubectl get pod -l app=app1 -o name) -- touch /data/test-file.txt
```

Verify file exists in app2

```bash
    kubectl exec $(kubectl get pod -l app=app2 -o name) -- ls -la /mnt/shared-data/
```
