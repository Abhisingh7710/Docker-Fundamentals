variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "Target deployment region"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "Free-tier eligible instance type sizing"
}

variable "key_name" {
  type        = string
  default     = "Ab"
  description = "The name of your existing EC2 security key pair in Mumbai"
}