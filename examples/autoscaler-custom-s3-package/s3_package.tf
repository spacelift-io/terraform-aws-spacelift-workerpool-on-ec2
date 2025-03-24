# This is just a toy example config that pulls the autoscaler binary from GitHub
# and hosts it in S3. This setup allows a simple plan/apply to work directly on
# the example. In actual usage, it would not be recommended to abuse the http data
# source and aws_s3_object resource in this manner. Instead, use an external process
# to host the binary in your own S3 bucket.

resource "aws_s3_bucket" "autoscaler_binary" {
  bucket_prefix = "spacelift-autoscaler-example-"
  force_destroy = true
}

data "http" "autoscaler_binary" {
  url = "https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${var.autoscaler_version}/ec2-workerpool-autoscaler_linux_${var.autoscaler_architecture}.zip"
}

resource "aws_s3_object" "autoscaler_binary" {
  key            = "releases/download/${var.autoscaler_version}/ec2-workerpool-autoscaler_linux_${var.autoscaler_architecture}.zip"
  bucket         = aws_s3_bucket.autoscaler_binary.id
  content_base64 = data.http.autoscaler_binary.response_body_base64
  content_type   = "application/octet-stream"
}
