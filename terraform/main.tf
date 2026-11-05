# AUSI Model Developer Infrastructure Platform — Terraform root module
# Adopted from the AUSI blueprint conversation (2026-11-04) with production fixes:
#   - S3 backend with state locking instead of local state
#   - Vault pinned to a non-sensitive dev mode by default; no inline tokens
#   - Helm release values sourced from the chart directory in this repo

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Populate via -backend-config or backend.hcl; never commit real IDs.
    bucket         = "REPLACE_ME_ausi_tfstate"
    key            = "ausi-platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_ME_ausi_tflock"
    encrypt        = true
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Namespace Provisioning -----------------------------------------------------

resource "kubernetes_namespace" "ausi_core" {
  metadata {
    name = "ausi-core"
    labels = {
      "security.ausi.dev/zero-trust"       = "enabled"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_namespace" "ausi_sandbox" {
  metadata {
    name = "ausi-sandbox"
    labels = {
      "security.ausi.dev/isolation-level"  = "gvisor"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# Helm Release for Infrastructure Dependencies -------------------------------

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  # Default is single-replica dev mode (no HA, no unseal secrets in VCS).
  # Flip server.ha.enabled + inject unseal keys via an external KMS out-of-band.
  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }
}

# Helm Release for AUSI Model Developer Platform ------------------------------

resource "helm_release" "ausi_platform" {
  name       = "ausi-platform"
  chart      = "${path.module}/../helm/ausi-platform"
  namespace  = kubernetes_namespace.ausi_core.metadata[0].name
  depends_on = [helm_release.vault]

  values = [
    file("${path.module}/../helm/ausi-platform/values.yaml")
  ]
}
