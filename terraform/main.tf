provider "google-beta" {
  credentials                       = "${file("account.json")}"
  project                           = "${var.project}"
  region                            = "${var.region}"
}

resource "google_compute_router" "rlt-router" {
  name                              = "${var.cluster_name}-router"
  network                           = "default"
  project                           = "${var.project}"
  region                            = "${var.region}"
}

resource "google_compute_subnetwork" "rlt_subnetwork" {
  name                              = "${var.cluster_name}"
  ip_cidr_range                     = "10.2.0.0/16"
  project                           = "${var.project}"
  region                            = "${var.region}"
  network                           = "${google_compute_network.rlt_network.self_link}"
}

module "cloud-nat" {
  source                            = "terraform-google-modules/cloud-nat/google"
  region                            = "${var.region}"
  network                           = "default"
  project_id                        = "${var.project}"
  router                            = "${google_compute_router.rlt-router.name}"
}

resource "google_compute_network" "rlt_network" {
  name                              = "container-network"
  auto_create_subnetworks           = false
  project                           = "${var.project}"
}

resource "google_container_cluster" "rlt_cluster" {
  project                           = "${var.project}"
  name                              = "${var.cluster_name}"
  location                          = "${var.region}"
  remove_default_node_pool          = true
  network                           = "${google_compute_network.rlt_network.name}"
  subnetwork                        = "${google_compute_subnetwork.rlt_subnetwork.name}"
  private_cluster_config {
    enable_private_endpoint         = false
    enable_private_nodes            = true
    master_ipv4_cidr_block          = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.0.0.0/16"
    services_ipv4_cidr_block = "10.1.0.0/16"
  }

  lifecycle {
    ignore_changes = ["initial_node_count", "network_policy", "node_config", "node_pool"]
  }

  node_pool {
    name = "default-pool"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
        cidr_block   = "${var.trusted_ip}"
        display_name = "Trusted_ip"
      }
  }
}

resource "google_container_node_pool" "rlt_cluster_np" {
  name                                    = "${var.cluster_name}-np"
  project                                 = "${var.project}"
  location                                = "${var.region}"
  cluster                                 = "${google_container_cluster.rlt_cluster.name}"
  initial_node_count                      = 1

  lifecycle {
    ignore_changes = ["node_count"]
  }

  autoscaling {
    min_node_count = "${var.min_nodes}"
    max_node_count = "${var.max_nodes}"
  }

  management {
    auto_repair  = true
    auto_upgrade = "${var.auto_upgrade}"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/pubsub",
    ]
    machine_type = "${var.machine_type}"

  }
}

