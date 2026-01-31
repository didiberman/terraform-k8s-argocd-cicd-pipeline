variable "hcloud_token" {
  sensitive = true
}

resource "hcloud_server" "talos" {
  name        = "talos-test-1"
  image       = "ubuntu-24.04" # Dummy image, we will boot from ISO
  server_type = "cpx22"
  location    = "fsn1"
  iso         = "hcloud-v1-11-2-amd64.iso"

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = "v1.11"
}

data "talos_machine_configuration" "this" {
  cluster_name       = "talos-test"
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${hcloud_server.talos.ipv4_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v1.11"
  kubernetes_version = "v1.30.0"
}

data "talos_client_configuration" "this" {
  cluster_name         = "talos-test"
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [hcloud_server.talos.ipv4_address]
}

resource "talos_machine_configuration_apply" "this" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = hcloud_server.talos.ipv4_address
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.talos.ipv4_address
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.talos.ipv4_address
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talos_node_ip" {
  value = hcloud_server.talos.ipv4_address
}

resource "hcloud_server" "talos_worker" {
  name        = "talos-test-worker-1"
  image       = "ubuntu-24.04"
  server_type = "cpx22"
  location    = "fsn1"
  iso         = "hcloud-v1-11-2-amd64.iso"

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

data "talos_machine_configuration" "worker" {
  cluster_name       = "talos-test"
  machine_type       = "worker"
  cluster_endpoint   = "https://${hcloud_server.talos.ipv4_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v1.11"
  kubernetes_version = "v1.30.0"
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = hcloud_server.talos_worker.ipv4_address
}
