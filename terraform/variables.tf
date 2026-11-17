variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Choose staging or production."
  }
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "initial_image" {
  type        = string
  description = "Existing readable bootstrap image; use an immutable digest. ECR authentication is automatic."
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._:/@-]+$", var.initial_image))
    error_message = "Provide a registry image reference without shell metacharacters."
  }
}
variable "application_cidrs" {
  type        = list(string)
  default     = []
  description = "Approved source CIDRs for app port 8080. Default denies all inbound; SSM smoke tests need no ingress."
  validation {
    condition     = alltrue([for cidr in var.application_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Use explicit IPv4 source CIDRs; unrestricted internet ingress is forbidden."
  }
}
variable "log_retention_days" {
  type    = number
  default = 7
}
variable "github_repository" {
  type    = string
  default = "Iftisam-sandik/devops-engineer-assessment"
}
variable "github_environment" {
  type    = string
  default = "production"
}
variable "create_github_oidc_provider" {
  type        = bool
  default     = false
  description = "Use an existing account provider by default; set true only after confirming none exists."
}
