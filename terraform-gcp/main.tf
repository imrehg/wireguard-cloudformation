variable "vpn_name" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "machine_type" {
  type    = string
  default = "f1-micro"
}

provider "google" {
  project = var.project
  region  = var.region
}

data "google_compute_zones" "available" {
}

resource "google_compute_address" "vpn_ip_address" {
  name         = "vpn-server-address-${var.vpn_name}"
  address_type = "EXTERNAL"
  region       = var.region
}

resource "google_compute_network" "vpn-network" {
  name                    = "vpn-network-${var.vpn_name}"
  mtu                     = 1500
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpn-subnetwork" {
  name          = "vpn-internal-subnetwork-${var.vpn_name}"
  ip_cidr_range = "10.30.0.0/16"
  region        = var.region
  network       = google_compute_network.vpn-network.id
}

resource "google_filestore_instance" "vpn_config_store" {
  name = "vpn-config-store-${var.vpn_name}"
  zone = data.google_compute_zones.available.names[0]
  // No real point setting up SSD probably
  tier = "BASIC_HDD"

  file_shares {
    // Minimum size
    capacity_gb = 2560
    name        = "config_share_vpn"
  }

  networks {
    // network = "default"
    network = google_compute_network.vpn-network.name
    modes   = ["MODE_IPV4"]
  }
}

// A single Compute Engine instance
resource "google_compute_instance" "vpn-instance" {
  name                      = "vpn-server-${var.vpn_name}"
  machine_type              = var.machine_type
  zone                      = google_filestore_instance.vpn_config_store.zone
  can_ip_forward            = true
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  metadata_startup_script = replace(file("${path.module}/startup.sh"), "REPLACE_VPN_FILESTORE_IP", google_filestore_instance.vpn_config_store.networks.0.ip_addresses.0)

  network_interface {
    // network = "default"
    subnetwork = google_compute_subnetwork.vpn-subnetwork.name
    access_config {
      nat_ip = google_compute_address.vpn_ip_address.address
    }
  }

}

resource "google_compute_firewall" "vpn-ports-inbound" {
  name        = "vpn-inbound-access-${var.vpn_name}"
  description = "Required ports for Wireguard and management access."
  // network     = "default"
  network = google_compute_network.vpn-network.name

  allow {
    protocol = "udp"
    ports    = [51820]
  }

  allow {
    protocol = "tcp"
    ports    = [22]
  }
}

output "vpn_ip" {
  value = google_compute_address.vpn_ip_address.address
}
