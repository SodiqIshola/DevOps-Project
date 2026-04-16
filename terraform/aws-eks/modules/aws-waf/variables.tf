
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "scope" {
  description = "WAF scope: REGIONAL (ALB/API GW) or CLOUDFRONT"
  type        = string

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  description = "Default WAF action"
  type = object({
    allow = optional(bool)
    block = optional(bool)
  })

  default = {
    allow = true
  }
}

variable "enable_managed_common_rules" {
  description = "Enable AWS managed common rule set"
  type        = bool
  default     = true
}

variable "enable_managed_aws_rules" {
  description = "Enable AWS managed rule sets (extra protection)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}