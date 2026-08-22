  data "aws_iam_policy_document" "s3" {
    statement {
      actions   = ["s3:GetObject"]
      resources = ["${var.s3_bucket_arn}/*"]
      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.cf.arn]
      }
    }
  }

  resource "aws_s3_bucket_policy" "cdn_oac_policy" {
    bucket = var.s3_bucket_id
    policy = data.aws_iam_policy_document.s3.json
  }

  resource "aws_cloudfront_origin_access_control" "s3_oac" {
    name                              = "s3_oac_policy"
    description                       = "s3_oac_policy"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
  }

  resource "aws_cloudfront_distribution" "cf" {
    origin {
      domain_name              = var.s3_bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
      origin_id                = "s3_origin"
      origin_path              = var.origin_path
    }

    origin {
      domain_name = trimsuffix(replace(var.lambda_function_url, "https://", ""), "/")
      origin_id   = "lambda_origin"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }

    enabled             = true
    is_ipv6_enabled     = false
    comment             = "CloudFront For S3, ALB"
    default_root_object = var.default_root_object
      
    default_cache_behavior {
      cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      target_origin_id = "s3_origin"
      

      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]

      compress = true
      viewer_protocol_policy = "redirect-to-https"
    }

    ordered_cache_behavior {
      path_pattern           = "/v1/book"
      target_origin_id       = "lambda_origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]

      cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    }

    price_class = "PriceClass_All"

    restrictions {
      geo_restriction {
        restriction_type = "none"
        locations        = []
      }
    }
    
    viewer_certificate {
      cloudfront_default_certificate = true
    }

    web_acl_id = var.enable_waf ? var.waf_id : null

    tags = var.tags
  }

  resource "aws_cloudfront_function" "this" {
    count   = var.enable_cloudfront_function ? 1 : 0

    name    = var.cloudfront_function_name
    runtime = var.cloudfront_function_runtime
    publish = var.cloudfront_function_publish
    code    = file("${path.module}/../../src${var.cloudfront_function_code_path}")
  }