# 자동화용 bastion(mgmt) 인스턴스 역할.
# eksctl/kubectl/docker/aws cli 로 전 구간을 자동 프로비저닝하기 위해 AdministratorAccess 사용.
# (연습/구축용 리소스이며, 실채점 전 destroy 하거나 wskorea26-vpc 밖에서 운용할 것)
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
