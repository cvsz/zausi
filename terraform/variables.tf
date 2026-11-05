variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to the target Kubernetes cluster configuration file."
}

variable "gpu_node_selector" {
  type        = map(string)
  default     = { "accelerator/gpu" = "nvidia-a100" }
  description = "Node labels required for GPU execution scheduling."
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region hosting the Terraform remote state bucket and lock table."
}
