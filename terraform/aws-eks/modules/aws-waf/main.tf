resource "aws_wafv2_web_acl" "this" {
  name  = "${var.cluster_name}-waf"
  scope = var.scope 

  # --- Default Action Logic ---
  # These dynamic blocks ensure only ONE action (Allow or Block) is active.
  # If 'allow' is defined in variables, it uses that; otherwise, it checks 'block'.
  dynamic "default_action" {
    for_each = var.default_action.allow != null ? [1] : []
    content {
      allow {}
    }
  }

  dynamic "default_action" {
    for_each = var.default_action.block != null ? [1] : []
    content {
      block {}
    }
  }

  ####################################################
  # Managed Rule Group: Common Rule Set (CRS)
  ####################################################
  # This is the "Core" protection. It blocks common threats like 
  # SQL Injection, Cross-Site Scripting (XSS), and large request bodies.
  dynamic "rule" {
    for_each = var.enable_managed_common_rules ? [1] : []

    content {
      name     = "AWSManagedCommonRules"
      priority = 1 # Lower numbers are evaluated first

      override_action {
        none {} # Set to 'count {}' if you want to test without actually blocking
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-commonRules"
        sampled_requests_enabled   = true
      }
    }
  }

  ####################################################
  # Amazon IP Reputation List
  ####################################################
  # Blocks traffic from known malicious sources, bots, 
  # and IPs identified by Amazon's internal threat intelligence.
  dynamic "rule" {
    for_each = var.enable_managed_aws_rules ? [1] : []

    content {
      name     = "AWSManagedAdditionalRules"
      priority = 2

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-ipReputation"
        sampled_requests_enabled   = true
      }
    }
  }

  # --- Global Visibility Config ---
  # Controls how metrics appear in the WAF CloudWatch dashboard.
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-main-waf-metrics"
    sampled_requests_enabled   = true # Required to see the "Sampled Requests" in the UI
  }

  tags = var.tags
}







