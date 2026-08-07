# 8. EKS Secret(Envelope) 암호화용 CMK : alias/wskorea26-eks-key
resource "aws_kms_key" "eks" {
  description             = "CMK for ${var.project} EKS secrets envelope encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "${var.project}-eks-key" }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project}-eks-key"
  target_key_id = aws_kms_key.eks.key_id
}
