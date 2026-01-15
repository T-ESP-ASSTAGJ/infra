[azure_vms]
${vm_name} ansible_host=${vm_ip} k8s_advertise_address=${vm_private_ip}

[k8s_control_plane]
${vm_name}

[k8s_workers]
# Add worker nodes here when available

[azure_vms:vars]
ansible_user=${admin_user}
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3