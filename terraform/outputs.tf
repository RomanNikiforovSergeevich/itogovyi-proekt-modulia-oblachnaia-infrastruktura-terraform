output "vm_public_ip" {
  value       = yandex_compute_instance.app-vm.network_interface.0.nat_ip_address
  description = "Public IP address of the VM"
}

output "registry_id" {
  value       = yandex_container_registry.app-registry.id
  description = "ID of the Container Registry"
}

output "mysql_cluster_id" {
  value       = yandex_mdb_mysql_cluster.app-mysql.id
  description = "ID of the MySQL cluster"
}
