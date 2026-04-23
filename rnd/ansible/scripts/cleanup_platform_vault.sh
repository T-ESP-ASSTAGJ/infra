vault lease revoke -force -prefix platform-database/

# 1. Delete the Kubernetes auth role
vault delete auth/kubernetes/role/platform-app-role

# 2. Delete the access policy
vault policy delete platform-access-policy

# 3. Delete the dynamic database roles
vault delete platform-database/roles/platform-admin-role
vault delete platform-database/roles/platform-readwrite-role

# 4. Delete the database connection configuration
vault delete platform-database/config/platform-database-connection

# 5. Disable the entire 'platform-database' secrets engine
vault secrets disable platform-database