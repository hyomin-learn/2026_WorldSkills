#=============== bastion-role ===============
# Admin role so the bastion can run eksctl (creates CFN stacks / IAM / EC2),
# kubectl, helm, and push to ECR without per-service policies.
resource "aws_iam_role" "bastion" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.instance_name}-role" }
}

resource "aws_iam_role_policy_attachment" "bastion_admin" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.instance_name}-role"
  role = aws_iam_role.bastion.name
}
