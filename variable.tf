variable "aws_region" {
  type        = string
  description = "AWS region for infrastructure deployment"
  default     = "ap-southeast-2"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key ID"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Access Key"
  sensitive   = true
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
  default     = "ami-06259b63260eddc13"
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance Type"
  default     = "t3.micro"
}

variable "instance_name" {
  type        = string
  description = "Name tag for the EC2 instance"
  default     = "my-terraform-EC2"
}