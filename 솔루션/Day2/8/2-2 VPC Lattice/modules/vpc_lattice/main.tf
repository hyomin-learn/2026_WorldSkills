# 1. 타겟 그룹 생성
resource "aws_vpclattice_target_group" "this" {
  name = "skills-lattice-order-tg"
  type = "INSTANCE"
  
  config {
    vpc_identifier = var.vpc_ids["vpc_2"]
    port           = 8080
    protocol       = "HTTP"

    health_check {
      enabled                   = true
      path                      = "/health" 
      port                      = 8080      
      protocol                  = "HTTP"
      protocol_version          = "HTTP1"
      healthy_threshold_count   = 2
      unhealthy_threshold_count = 2
      
      matcher {
        value = "200"
      }
    }
  } 
}

resource "aws_vpclattice_target_group_attachment" "this" {
  target_group_identifier = aws_vpclattice_target_group.this.id

  target {
    id   = var.lattice_service_instance_id 
    port = 8080
  }
}

resource "aws_vpclattice_service" "this" {
  name      = "skills-lattice-order-service"
  auth_type = "NONE"
}

resource "aws_vpclattice_service_network" "this" {
  name      = "skills-lattice-sn"
  auth_type = "NONE"
}

resource "aws_vpclattice_service_network_service_association" "this" {
  service_identifier         = aws_vpclattice_service.this.id
  service_network_identifier = aws_vpclattice_service_network.this.id
}

resource "aws_vpclattice_service_network_vpc_association" "this" {
  service_network_identifier = aws_vpclattice_service_network.this.id
  vpc_identifier             = var.vpc_ids["vpc_1"]
  security_group_ids         = [var.client_assoc_sg_id]
}

resource "aws_vpclattice_listener" "this" {
  name               = "skills-lattice-http-listener"
  service_identifier = aws_vpclattice_service.this.id
  port               = 80
  protocol           = "HTTP"

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.this.id
        weight                  = 100
      }
    }
  }
}