moved {
  from = data.aws_ami.this
  to   = data.aws_ami.this[0]
}
