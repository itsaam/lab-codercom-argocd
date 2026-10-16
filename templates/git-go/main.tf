terraform {
  required_providers {
    coder      = { source = "coder/coder", version = "2.5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "2.36.0" }
  }
}
provider "coder" {}
provider "kubernetes" { config_path = null }
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  dir            = "/home/coder/project"
  startup_script = "#!/bin/sh\nset -eu\nmkdir -p /home/coder/project\ngit --version\ngo version\n"
}
resource "kubernetes_persistent_volume_claim_v1" "home" {
  wait_until_bound = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = "workspaces"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources { requests = { storage = "2Gi" } }
  }
}
resource "kubernetes_pod_v1" "workspace" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = "workspaces"
    labels    = { app = "coder-workspace" }
  }
  spec {
    automount_service_account_token = false
    security_context {
      run_as_user  = 1000
      run_as_group = 1000
      fs_group     = 1000
    }
    container {
      name    = "dev"
      image   = "golang:1.24.2-bookworm"
      command = ["sh", "-c", coder_agent.main.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "USER"
        value = "coder"
      }
      env {
        name  = "LOGNAME"
        value = "coder"
      }
      env {
        name  = "SHELL"
        value = "/bin/bash"
      }
      env {
        name  = "HOME"
        value = "/home/coder"
      }
      resources {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { cpu = "1", memory = "2Gi" }
      }
      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }
      security_context { allow_privilege_escalation = false }
    }
    volume {
      name = "home"
      persistent_volume_claim { claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name }
    }
  }
}
