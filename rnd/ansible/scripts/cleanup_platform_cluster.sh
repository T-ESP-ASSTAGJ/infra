# 1. Delete the CNPG custom resources
kubectl delete cluster platform-database-cluster -n database
kubectl delete pooler pooler-platform-rw -n database
kubectl delete scheduledbackup platform-backup -n database
kubectl delete database platform-declarative-db -n database

# 2. Delete the Kubernetes secrets
kubectl delete secret cloudflare -n database
kubectl delete secret platform-database-internal-tls -n database
# (And any other platform secrets, like '-superuser')

# 3. Delete the Persistent Volume (The actual data)
kubectl delete pvc -n database -l cnpg.io/cluster=platform-database-cluster

# 1. Delete the CNPG custom resources
kubectl delete cluster bytebase-database-cluster -n bytebase
kubectl delete pooler pooler-bytebase-rw -n bytebase
kubectl delete scheduledbackup bytebase-backup -n bytebase
kubectl delete database bytebase-declarative-db -n bytebase

# 2. Delete the Kubernetes secrets
kubectl delete secret cloudflare -n bytebase
kubectl delete secret bytebase-database-internal-tls -n bytebase
# (And any other platform secrets, like '-superuser')

# 3. Delete the Persistent Volume (The actual data)
kubectl delete pvc -n bytebase -l cnpg.io/cluster=platform-bytebase-cluster