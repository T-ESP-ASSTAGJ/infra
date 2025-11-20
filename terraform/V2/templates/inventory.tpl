all:
  vars:
    ansible_connection: ssh
    ansible_python_interpreter: /usr/bin/python3
    ansible_user: ${ssh_user}
    environment: ${environment}

  children:
    api_servers:
      hosts:
        api:
          ansible_host: ${api_vm_ip}
          private_ip: ${api_vm_private_ip}
          vm_type: api

    web_servers:
      hosts:
        web:
          ansible_host: ${web_vm_ip}
          private_ip: ${web_vm_private_ip}
          vm_type: web

    database_servers:
      hosts:
        database:
          ansible_host: ${db_vm_ip}
          private_ip: ${db_vm_private_ip}
          vm_type: database