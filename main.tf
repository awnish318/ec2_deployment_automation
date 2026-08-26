provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "ServerA" {
  count =4
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "${var.instance_name}-${count.index + 1}"
  }
}

