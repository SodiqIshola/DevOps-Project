resource "aws_wafv2_web_acl" "this" {
  name  = "fargate-app-waf"
  scope = "REGIONAL" # Use CLOUDFRONT for CloudFront, REGIONAL for ALB/Fargate

  default_action {
    allow {}
  }

  ####################################################
  # Managed Rule Group: Common Rule Set (CRS)
  ####################################################
  rule {
    name     = "AWSManagedCommonRules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRules"
      sampled_requests_enabled   = true
    }
  }

  ####################################################
  # Amazon IP Reputation List
  ####################################################
  rule {
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
      metric_name                = "ipReputation"
      sampled_requests_enabled   = true
    }
  }

  # --- Global Visibility Config (REQUIRED) ---
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "main-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = "production"
  }
}


# Associate the WAF with your ALB
resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.fargate_waf.arn
}
