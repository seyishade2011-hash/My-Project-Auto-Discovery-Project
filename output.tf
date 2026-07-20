output "vpc_id" {
  value = module.vpc.vpc_id
}

output "bastion_sg" {
  value = module.bastion.bastion_sg_id
}

output "nexus_url" {
  value = module.nexus.nexus_url
}

output "sonarqube_url" {
  value = module.sonarqube.sonarqube_url
}

output "vault_sg_cidr" {
  value = var.vault_sg_cidr
}

output "vault_vpc_cidr" {
  value = var.vault_vpc_cidr
}

output "database_endpoint" {
  value = module.database.db_endpoint
}

output "ansible_ip" {
  value = module.ansible.public_ip
}