locals {
  s3_origin_id = "${var.project}-cdn-ab-s3-origin"
}

###############################################################################
# 2. KeyValueStore 구성
#    - 이름 : skillsphone-cdn-ab-config
#    - 키   : weight / version_a / version_b
###############################################################################

resource "aws_cloudfront_key_value_store" "ab" {
  name    = "${var.project}-cdn-ab-config"
  comment = "A/B weight & version paths for CloudFront Function"
}

resource "aws_cloudfrontkeyvaluestore_key" "weight" {
  key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
  key                 = "weight"
  value               = "0.3"
}

resource "aws_cloudfrontkeyvaluestore_key" "version_a" {
  key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
  key                 = "version_a"
  value               = "/version-a/index.html"
}

resource "aws_cloudfrontkeyvaluestore_key" "version_b" {
  key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
  key                 = "version_b"
  value               = "/version-b/index.html"
}

###############################################################################
# 3. CloudFront Function 구성 (cloudfront-js-2.0, LIVE 스테이지)
#    - viewer-request : skillsphone-cdn-ab-req-fn (KeyValueStore 연결)
#    - viewer-response: skillsphone-cdn-ab-res-fn
###############################################################################

resource "aws_cloudfront_function" "req" {
  name    = "${var.project}-cdn-ab-req-fn"
  runtime = "cloudfront-js-2.0"
  comment = "viewer-request : weight 기반 A/B 할당 및 URI 재조성"
  publish = true # LIVE 스테이지로 발행
  code    = file("${path.module}/functions/req.js")

  # viewer-request 함수에 KeyValueStore 연결
  key_value_store_associations = [aws_cloudfront_key_value_store.ab.arn]

  # 키가 먼저 기록된 뒤 함수가 LIVE 로 발행되도록 보장
  depends_on = [
    aws_cloudfrontkeyvaluestore_key.weight,
    aws_cloudfrontkeyvaluestore_key.version_a,
    aws_cloudfrontkeyvaluestore_key.version_b,
  ]
}

resource "aws_cloudfront_function" "res" {
  name    = "${var.project}-cdn-ab-res-fn"
  runtime = "cloudfront-js-2.0"
  comment = "viewer-response : 할당 버전을 x-sp-ab 쿠키로 발급"
  publish = true # LIVE 스테이지로 발행
  code    = file("${path.module}/functions/res.js")
}

###############################################################################
# 4. Policy 구성 (AWS Managed Policy 미사용)
#    - Cache Policy   : skillsphone-cdn-ab-cache-policy
#                       x-sp-ab 쿠키를 캐시 키에 포함 / TTL 0·300·3600
#    - Response Header: Security Header 추가
###############################################################################

resource "aws_cloudfront_cache_policy" "ab" {
  name        = "${var.project}-cdn-ab-cache-policy"
  comment     = "Cache key includes x-sp-ab cookie for A/B separation"
  min_ttl     = 0
  default_ttl = 300
  max_ttl     = 3600

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "whitelist"
      cookies {
        items = ["x-sp-ab"]
      }
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project}-cdn-ab-security-headers"
  comment = "Security headers for A/B distribution"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

###############################################################################
# OAC (Origin Access Control) - S3 오리진을 CloudFront 로만 접근하도록 보호
###############################################################################

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project}-cdn-ab-oac"
  description                       = "OAC for skillsphone landing A/B bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

###############################################################################
# 5. CloudFront Distribution 구성
#    - 이름(태그/주석) : skillsphone-cdn-ab-distribution
#    - HTTP 접속 시 HTTPS 로 리디렉션
#    - viewer-request / viewer-response 함수 + 캐시 정책 연결
#    - Pay-as-you-go (on-demand) : 모든 엣지 로케이션 사용
###############################################################################

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-cdn-ab-distribution"
  price_class         = "PriceClass_All"
  default_root_object = "index.html"

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy  = "redirect-to-https" # HTTP -> HTTPS 리디렉션
    allowed_methods         = ["GET", "HEAD"]
    cached_methods          = ["GET", "HEAD"]
    compress                = true

    cache_policy_id            = aws_cloudfront_cache_policy.ab.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.req.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.res.arn
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

  tags = {
    Name = "${var.project}-cdn-ab-distribution"
  }
}

###############################################################################
# S3 버킷 정책 : 해당 CloudFront 배포(OAC)만 GetObject 허용
###############################################################################

resource "aws_s3_bucket_policy" "oac" {
  bucket = var.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${var.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}
