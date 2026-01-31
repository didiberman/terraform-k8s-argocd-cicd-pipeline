terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.49.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
  }

  backend "s3" {
    bucket         = "k8s-terraform-state-yadid"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "k8s-terraform-lock"
    encrypt        = true
  }
}

variable "hcloud_token" {
  sensitive = true
}

variable "cloudflare_api_token" {
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "talos" {}

resource "hcloud_network" "k8s_net" {
  name     = "k8s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k8s_subnet" {
  network_id   = hcloud_network.k8s_net.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_firewall" "k8s_firewall" {
  name = "k8s-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443" # K8s API
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "50000" # Talos API
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow all internal traffic
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "any"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# Talos Configuration
resource "talos_machine_secrets" "this" {
  talos_version = "v1.11"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = "talos-k8s"
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${hcloud_server.master.ipv4_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v1.11"
  kubernetes_version = "v1.30.0"
}

data "talos_machine_configuration" "worker" {
  cluster_name       = "talos-k8s"
  machine_type       = "worker"
  cluster_endpoint   = "https://${hcloud_server.master.ipv4_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v1.11"
  kubernetes_version = "v1.30.0"
}

data "talos_client_configuration" "this" {
  cluster_name         = "talos-k8s"
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [hcloud_server.master.ipv4_address]
}

# Master Node
resource "hcloud_server" "master" {
  name         = "talos-master"
  image        = "ubuntu-24.04"
  server_type  = "cpx22"
  location     = "nbg1"
  iso          = "hcloud-v1-11-2-amd64.iso"
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  network {
    network_id = hcloud_network.k8s_net.id
    ip         = "10.0.1.5"
  }

  depends_on = [hcloud_network_subnet.k8s_subnet]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = hcloud_server.master.ipv4_address
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.master.ipv4_address
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.master.ipv4_address
}

# Worker Nodes
resource "hcloud_server" "worker1" {
  name         = "talos-worker-1"
  image        = "ubuntu-24.04"
  server_type  = "cpx22"
  location     = "fsn1"
  iso          = "hcloud-v1-11-2-amd64.iso"
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  network {
    network_id = hcloud_network.k8s_net.id
    ip         = "10.0.1.6"
  }
  depends_on = [hcloud_network_subnet.k8s_subnet]
}

resource "talos_machine_configuration_apply" "worker1" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = hcloud_server.worker1.ipv4_address
}

resource "hcloud_server" "worker2" {
  name         = "talos-worker-2"
  image        = "ubuntu-24.04"
  server_type  = "cpx22"
  location     = "hel1"
  iso          = "hcloud-v1-11-2-amd64.iso"
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  network {
    network_id = hcloud_network.k8s_net.id
    ip         = "10.0.1.7"
  }
  depends_on = [hcloud_network_subnet.k8s_subnet]
}

resource "talos_machine_configuration_apply" "worker2" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = hcloud_server.worker2.ipv4_address
}

resource "hcloud_server" "worker3" {
  name         = "talos-worker-3"
  image        = "ubuntu-24.04"
  server_type  = "cpx22"
  location     = "sin"
  iso          = "hcloud-v1-11-2-amd64.iso"
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  network {
    network_id = hcloud_network.k8s_net.id
    ip         = "10.0.1.8"
  }
  depends_on = [hcloud_network_subnet.k8s_subnet]
}

resource "talos_machine_configuration_apply" "worker3" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = hcloud_server.worker3.ipv4_address
}

resource "hcloud_server" "worker4" {
  name         = "talos-worker-4"
  image        = "ubuntu-24.04"
  server_type  = "cpx11"
  location     = "ash"
  iso          = "hcloud-v1-11-2-amd64.iso"
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  network {
    network_id = hcloud_network.k8s_net.id
    ip         = "10.0.1.9"
  }
  depends_on = [hcloud_network_subnet.k8s_subnet]
}

resource "talos_machine_configuration_apply" "worker4" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = hcloud_server.worker4.ipv4_address
}

# Cloudflare DNS
resource "cloudflare_record" "k8s_lbs" {
  zone_id = var.cloudflare_zone_id
  name    = "k8s"
  content = hcloud_server.master.ipv4_address
  type    = "A"
  proxied = true
}

# Bootstrapping (ArgoCD & CNI)
resource "null_resource" "k8s_bootstrap" {
  depends_on = [
    talos_cluster_kubeconfig.this,
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.worker1,
    talos_machine_configuration_apply.worker2,
    talos_machine_configuration_apply.worker3,
    talos_machine_configuration_apply.worker4
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "${resource.talos_cluster_kubeconfig.this.kubeconfig_raw}" > kubeconfig.yaml
      export KUBECONFIG=./kubeconfig.yaml

      echo "⏳ Waiting for API Server..."
      until kubectl get nodes; do echo "Waiting for API..."; sleep 5; done

      echo "📦 Installing Flannel CNI..."
      kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

      echo "⏳ Waiting for Nodes to be Ready..."
      kubectl wait --for=condition=Ready nodes --all --timeout=300s

      echo "📦 Installing ArgoCD..."
      kubectl create namespace argocd || true
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      
      echo "⏳ Waiting for ArgoCD Server..."
      kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

      echo "🛡️ Installing Cert-Manager..."
      kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
      
      echo "⏳ Waiting for Cert-Manager..."
      kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s

      echo "🚦 Installing Traefik Ingress..."
      kubectl apply -f ../k8s/traefik.yaml

      echo "🚀 Applying App of Apps..."
      kubectl apply -f ../k8s/argocd-app.yaml
    EOT
  }
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "master_ip" {
  value = hcloud_server.master.ipv4_address
}
