resource "aws_eip" "this" {
  domain   = "vpc"
  instance = var.instance_id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.env_type}-eip"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Optional: Associate the EIP with the instance if not done automatically
resource "aws_eip_association" "this" {
  count         = var.associate_with_instance ? 1 : 0
  instance_id   = var.instance_id
  allocation_id = aws_eip.this.id
}
