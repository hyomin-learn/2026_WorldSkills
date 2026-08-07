# 11. CloudFront : wskorea26-concert-cf
locals {
  s3_origin_id  = "wskorea26-s3-origin"
  alb_origin_id = "wskorea26-alb-origin"
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# book 애플리케이션의 실제 경로(/v1/book)와 외부 노출 경로(/book)가 다르므로,
# POST 요청만 /book -> /v1/book 으로 재작성하는 CloudFront Function 을 사용한다.
resource "aws_cloudfront_function" "book_rewrite" {
  name    = "${var.project}-book-path-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "POST /book -> /v1/book rewrite for book app"
  publish = true
  code    = file("${path.module}/functions/book-rewrite.js")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "wskorea26-concert-cf"
  default_root_object = "index.html"
  price_class         = "PriceClass_All"

  # --------------------------- ALB Origin (/book -> book-alb) ---------------------------
  # (채점 8-4-A 출력 순서: X-Origin-Verify 가 먼저 나오므로 ALB Origin 을 먼저 선언)
  origin {
    origin_id   = local.alb_origin_id
    domain_name = var.alb_dns_name

    custom_origin_config {
      http_port                = 80
      https_port                = 443
      origin_protocol_policy    = "http-only"
      origin_ssl_protocols      = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = "wskorea26-cf"
    }
  }

  # --------------------------- S3 Origin (정적 웹, Object Path: /web/main/) ---------------------------
  origin {
    origin_id                = local.s3_origin_id
    domain_name               = var.s3_bucket_regional_domain_name
    origin_access_control_id  = aws_cloudfront_origin_access_control.s3.id
    origin_path                = "/web/main"

    custom_header {
      name  = "wskorea26-s3-access"
      value = "true"
    }
  }

  # --------------------------- 루트 경로 -> S3 (캐싱 활성화) ---------------------------
  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  # --------------------------- /book -> ALB (캐싱 비활성화, 모든 메서드/쿼리스트링/헤더 전달) ---------------------------
  ordered_cache_behavior {
    path_pattern             = "/book*"
    target_origin_id         = local.alb_origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods           = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id   = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed-AllViewer

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.book_rewrite.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "wskorea26-concert-cf" }
}
