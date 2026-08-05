resource "aws_sfn_state_machine" "this" {
  name     = var.state_machine_name
  role_arn = var.role_arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/state_machine.json.tpl", {
    lambda_function_arn = var.lambda_function_arn
    bucket_name          = var.bucket_name
  })
}
