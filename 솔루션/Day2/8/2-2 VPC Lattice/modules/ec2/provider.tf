data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-minimal-kernel-default-x86_64"
}

data "aws_ec2_managed_prefix_list" "vpc_lattice" {
  name = "com.amazonaws.ap-northeast-1.vpc-lattice"
}