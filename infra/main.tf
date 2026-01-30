terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.49.1"
    }
  }
}

variable "hcloud_token" {
  sensitive = true
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "default" {
  name       = "k3s-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub") # Assumes user has this, otherwise we might need to generate one
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
}

resource "hcloud_server" "master" {
  name        = "k3s-master"
  image       = "ubuntu-22.04"
  server_type = "cx22" # Smallest available
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]
  
  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.5"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role = "server"
    token = "secretk3stoken" # In prod, use random string
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet
  ]
}

resource "hcloud_server" "worker" {
  name        = "k3s-worker-1"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s_firewall.id]

  network {
    network_id = hcloud_network.k3s_net.id
    ip         = "10.0.1.6"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    role  = "agent"
    token = "secretk3stoken"
    master_ip = hcloud_server.master.network[*].ip[0] # Internal IP
  })

  depends_on = [
    hcloud_network_subnet.k3s_subnet,
    hcloud_server.master
  ]
}

output "master_ip" {
  value = hcloud_server.master.ipv4_address
}
