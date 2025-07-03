#!/bin/bash

echo "Starting Kubernetes cluster setup..."

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Check nodes and their labels
echo "Checking cluster nodes and labels..."
kubectl get nodes --show-labels

# Add taints to nodes with app=mysql label
echo "Adding taints to MySQL nodes..."
MYSQL_NODES=$(kubectl get nodes -l app=mysql --no-headers | awk '{print $1}')
if [ -n "$MYSQL_NODES" ]; then
    for node in $MYSQL_NODES; do
        echo "Adding taint to node: $node"
        kubectl taint nodes $node app=mysql:NoSchedule --overwrite
    done
else
    echo "No nodes with app=mysql label found"
fi

# Verify taints
echo "Verifying taints on nodes..."
kubectl describe nodes | grep -A 3 Taints

# Deploy MySQL components
echo "Deploying MySQL components..."
kubectl apply -f .infrastructure/mysql/ns.yml
kubectl apply -f .infrastructure/mysql/configMap.yml
kubectl apply -f .infrastructure/mysql/secret.yml
kubectl apply -f .infrastructure/mysql/service.yml
kubectl apply -f .infrastructure/mysql/statefulSet.yml

# Wait for MySQL namespace to be ready
echo "Waiting for MySQL namespace to be ready..."
kubectl wait --for=condition=Ready pods -l app=mysql -n mysql --timeout=300s || echo "MySQL pods may still be starting..."

# Deploy TodoApp components
echo "Deploying TodoApp components..."
kubectl apply -f .infrastructure/app/ns.yml
kubectl apply -f .infrastructure/app/pv.yml
kubectl apply -f .infrastructure/app/pvc.yml
kubectl apply -f .infrastructure/app/secret.yml
kubectl apply -f .infrastructure/app/configMap.yml
kubectl apply -f .infrastructure/app/clusterIp.yml
kubectl apply -f .infrastructure/app/nodeport.yml
kubectl apply -f .infrastructure/app/hpa.yml
kubectl apply -f .infrastructure/app/deployment.yml

# Install Ingress Controller
echo "Installing Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Optional: Apply ingress rules if file exists
if [ -f ".infrastructure/ingress/ingress.yml" ]; then
    echo "Applying ingress rules..."
    kubectl apply -f .infrastructure/ingress/ingress.yml
fi

# Wait for TodoApp deployment to be ready
echo "Waiting for TodoApp deployment to be ready..."
kubectl wait --for=condition=available deployment/todoapp -n todoapp --timeout=300s || echo "TodoApp deployment may still be starting..."

echo "Deployment completed!"
echo ""
echo "=== Cluster Status ==="
kubectl get nodes -o wide
echo ""
echo "=== MySQL Pods ==="
kubectl get pods -n mysql -o wide
echo ""
echo "=== TodoApp Pods ==="
kubectl get pods -n todoapp -o wide
echo ""
echo "=== Services ==="
kubectl get svc -n mysql
kubectl get svc -n todoapp
echo ""
echo "=== HPA Status ==="
kubectl get hpa -n todoapp
echo ""
echo "=== Verification Commands ==="
echo "To verify Node Affinity and Anti-Affinity:"
echo "kubectl describe pod -n mysql | grep -A 10 -E '(Tolerations|Affinity)'"
echo "kubectl describe pod -n todoapp | grep -A 10 -E '(Tolerations|Affinity)'"
echo ""
echo "To check taint compliance:"
echo "kubectl describe nodes | grep -A 3 Taints"
echo ""
echo "To access the application:"
NODEPORT=$(kubectl get svc -n todoapp todoapp-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "NodePort not found")
if [ "$NODEPORT" != "NodePort not found" ]; then
    echo "Application available at: http://localhost:$NODEPORT"
else
    echo "Check NodePort service: kubectl get svc -n todoapp"
fi
