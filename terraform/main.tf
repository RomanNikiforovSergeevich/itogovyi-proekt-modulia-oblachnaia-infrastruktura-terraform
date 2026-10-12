terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}

resource "yandex_vpc_network" "app-network" {
  name = "app-network"
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = "app-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_security_group" "app-sg" {
  name       = "app-security-group"
  network_id = yandex_vpc_network.app-network.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "MySQL"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3306
  }

  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "app-vm" {
  name        = "app-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  service_account_id = "ajevp2202utp1fiu3d25"

  resources {
    cores  = 2
    memory = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type       = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app-subnet.id
    security_group_ids = [yandex_vpc_security_group.app-sg.id]
    nat                = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key)}"
    user-data = file("${path.module}/user-data.yaml")
  }
}

resource "yandex_mdb_mysql_cluster" "app-mysql" {
  name        = "app-mysql"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.app-network.id
  version     = "8.0"

  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-hdd"
    disk_size          = 10
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.app-subnet.id
  }

  security_group_ids = [yandex_vpc_security_group.app-sg.id]
}

resource "yandex_mdb_mysql_database" "app-db" {
  cluster_id = yandex_mdb_mysql_cluster.app-mysql.id
  name       = "app_db"
}

resource "yandex_mdb_mysql_user" "app-user" {
  cluster_id = yandex_mdb_mysql_cluster.app-mysql.id
  name       = "app_user"
  password   = var.db_password
  permission {
    database_name = yandex_mdb_mysql_database.app-db.name
  }
}

resource "yandex_container_registry" "app-registry" {
  name = "app-registry"
}

resource "yandex_lockbox_secret" "db-secret" {
  name = "db-password-secret"
}

resource "yandex_lockbox_secret_version" "db-secret-version" {
  secret_id = yandex_lockbox_secret.db-secret.id

  entries {
    key        = "password"
    text_value = var.db_password
  }
}
