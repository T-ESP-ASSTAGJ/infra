# =============================================================================
# MODULE OUTPUTS - DIGITALOCEAN VM
# =============================================================================

output "project_info" {
  description = "Project information"
  value = {
    id          = digitalocean_project.main.id
    name        = digitalocean_project.main.name
    environment = var.environment
    region      = var.region
  }
}

output "vpc_info" {
  description = "VPC information"
  value = {
    id       = digitalocean_vpc.main.id
    name     = digitalocean_vpc.main.name
    ip_range = digitalocean_vpc.main.ip_range
    region   = digitalocean_vpc.main.region
  }
}

output "droplet_info" {
  description = "Droplet information"
  value = {
    for idx, droplet in digitalocean_droplet.vm : droplet.name => {
      id         = droplet.id
      name       = droplet.name
      public_ip  = droplet.ipv4_address
      private_ip = droplet.ipv4_address_private
      status     = droplet.status
      vcpus      = droplet.vcpus
      memory     = droplet.memory
      disk       = droplet.disk
    }
  }
}

output "firewall_info" {
  description = "Firewall information"
  value = var.enable_firewall ? {
    id   = digitalocean_firewall.main[0].id
    name = digitalocean_firewall.main[0].name
  } : null
}

output "connection_info" {
  description = "Connection information for the VMs"
  value = {
    ssh_connections = {
      for idx, droplet in digitalocean_droplet.vm : droplet.name => "ssh root@${droplet.ipv4_address}"
    }
  }
}

output "tags" {
  description = "Created tags"
  value = {
    project     = digitalocean_tag.project_tag.name
    vm          = digitalocean_tag.vm_tag.name
    environment = digitalocean_tag.environment_tag.name
  }
}

output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
🚀 Deployment Summary:
   Project: ${var.project_name}-${var.environment}
   Region: ${var.region}
   VMs Created: ${var.vm_count}
   VM Size: ${var.droplet_size}
   VPC Range: ${digitalocean_vpc.main.ip_range}

📝 Next Steps:
   1. SSH to VMs: ssh root@<vm_public_ip>
   2. Check logs: tail -f /var/log/vm-deployment.log
   3. Install Kubernetes on these VMs

🏷️  All resources are tagged with: ${digitalocean_tag.project_tag.name}
EOT
}