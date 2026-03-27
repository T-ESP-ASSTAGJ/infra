[azure_vms]
jamlycp ansible_host=${cp_public_ip} k8s_advertise_address=${cp_private_ip}
jamlyw1 ansible_host=${w1_private_ip} k8s_advertise_address=${w1_private_ip}

[k8s_control_plane]
jamlycp

[k8s_workers]
jamlyw1

[k8s_workers:vars]
ansible_ssh_common_args=-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -W %h:%p ${admin_user}@${cp_public_ip}"

[azure_vms:vars]
ansible_user=${admin_user}
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
