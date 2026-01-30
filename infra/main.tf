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

variable "ssh_public_key" {
  type    = string
  default = ""
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
}

resource "hcloud_ssh_key" "default" {
  name       = "k3s-ssh-key"
  public_key = local.ssh_public_key
}

resource "hcloud_network" "k3s_net" {
  name     = "k3s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s_subnet" {
  network_id   = hcloud_network.k3s_net.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_firewall" "k3s_firewall" {
  name = "k3s-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
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
    port      = "80"
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

  # Allow all internal traffic for CNI (Flannel VXLAN/WireGuard) and Pod-to-Pod communication
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

resource "hcloud_server" "master" {
  name         = "k3s-master"
  image        = "ubuntu-22.04"
  server_type  = "cx23" # Smallest available
  location     = "nbg1"
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.5"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role      = "server"
    token     = "secretk3stoken" # In prod, use random string
    master_ip = ""               # Not used for server role, but required by template
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet
  ]
}

resource "hcloud_server" "worker" {
  name         = "k3s-worker-1"
  image        = "ubuntu-22.04"
  server_type  = "cx23"
  location     = "nbg1"
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.6"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role      = "agent"
    token     = "secretk3stoken"
    master_ip = "10.0.1.5" # Master's internal IP from network block
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet,
    hcloud_server.master
  ]
}

resource "hcloud_server" "worker2" {
  name         = "k3s-worker-2"
  image        = "ubuntu-22.04"
  server_type  = "cx23"
  location     = "nbg1"
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.7"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role      = "agent"
    token     = "secretk3stoken"
    master_ip = "10.0.1.5" # Master's internal IP from network block
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet,
    hcloud_server.master
  ]
}

output "master_ip" {
  value = hcloud_server.master.ipv4_address
}

resource "hcloud_server" "worker3" {
  name         = "k3s-worker-3"
  image        = "ubuntu-22.04"
  server_type  = "cx23"
  location     = "nbg1"
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.8"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role      = "agent"
    token     = "secretk3stoken"
    master_ip = "10.0.1.5"
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet,
    hcloud_server.master
  ]
}

resource "cloudflare_record" "k8s_lbs" {
  zone_id = var.cloudflare_zone_id
  name    = "k8s"
  content = hcloud_server.master.ipv4_address
  type    = "A"
  proxied = true
}

resource "null_resource" "k8s_bootstrap" {
  depends_on = [hcloud_server.master]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    host        = hcloud_server.master.ipv4_address
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🚀 Master node reached. Waiting 30s for cloud-init to stabilize...'",
      "sleep 30",

      "echo '⏳ Waiting for kubectl binary to be available...'",
      "until [ -f /usr/local/bin/kubectl ]; do echo '...still waiting for k3s install...'; sleep 10; done",

      "echo '⏳ Waiting for K3s nodes to be Ready...'",
      "until kubectl get nodes | grep -q 'Ready'; do echo '...waiting for nodes to report ready...'; sleep 10; done",

      "echo '📦 Installing ArgoCD...'",
      "kubectl create namespace argocd || true",
      "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml",
      "echo '⏳ Waiting for ArgoCD Server...'",
      "kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s",

      "echo '🛡️ Installing Cert-Manager...'",
      "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml",
      "echo '⏳ Waiting for Cert-Manager...'",
      "kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s",
    ]
  }

  # We apply the app manifest in a separate step or via file provisioner to get the file there first
  # But since the file is in git, we can just curl it or create it inline.
  # For simplicity, let's create it inline since it's small, or use a here-doc.
  provisioner "file" {
    source      = "../k8s/argocd-app.yaml"
    destination = "/root/argocd-app.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Applying Initial Configurations...'",
      "kubectl apply -f /root/argocd-app.yaml"
    ]
  }
}

output "kubeconfig_command" {
  value = "scp -i ~/.ssh/id_rsa root@${hcloud_server.master.ipv4_address}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-hetzner.yaml && sed -i '' 's/127.0.0.1/${hcloud_server.master.ipv4_address}/g' ~/.kube/k3s-hetzner.yaml"
}

output "argocd_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}
