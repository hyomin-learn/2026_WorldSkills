module "vpc" {
  source = "./modules/vpc" 
}

module "ec2" {
  source = "./modules/ec2"

  vpc_1_id            = module.vpc.vpc_1_id
  vpc_2_id            = module.vpc.vpc_2_id
  private_subnet_2_id = module.vpc.private_subnet_2_id
  public_subnet_1_id  = module.vpc.public_subnet_1_id
  lattice_service_dns = module.vpc_lattice.service_dns_name
}

module "vpc_lattice" {
  source = "./modules/vpc_lattice" 

  service_network_auth_type = "NONE"

  vpc_ids = {
    "vpc_1" = module.vpc.vpc_1_id
    "vpc_2" = module.vpc.vpc_2_id
  }

  client_assoc_sg_id          = module.ec2.security_group_client_assoc_id
  lattice_service_instance_id = module.ec2.skills_lattice_service_instance_id
}