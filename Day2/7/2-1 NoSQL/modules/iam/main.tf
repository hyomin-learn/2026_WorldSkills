#=============== app-ec2 role ===============
resource "aws_iam_role" "app" {
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

resource "aws_iam_role_policy_attachment" "app_dynamodb" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.instance_name}-role"
  role = aws_iam_role.app.name

  tags = { Name = "${var.instance_name}-instance-profile" }
}
