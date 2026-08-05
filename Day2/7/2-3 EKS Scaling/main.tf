module "vpc" {
  source = "./module/vpc"
}

module "ec2" {
  source    = "./module/ec2"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_a_id 
  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_c_id = module.vpc.private_subnet_b_id 
  sqs_queue_url       = module.sqs.queue_url
}

module "sqs" {
  source = "./module/sqs"

  name                        = "my-application-queue"
  fifo_queue                  = false 
  delay_seconds               = 0
  max_message_size            = 262144  
  message_retention_seconds   = 345600  
  receive_wait_time_seconds   = 0
  visibility_timeout_seconds  = 30
  
  enable_kms                  = false
  sqs_managed_sse_enabled     = true

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}