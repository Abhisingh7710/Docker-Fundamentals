variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "Target AWS deployment region"
}

variable "aws_access_key" {
  type        = string
  default     = "yourAWSAccessKey"
  description = "IAM user access key ID tracking "
}

variable "aws_secret_key" {
  type        = string
  default     = "yourAWSSecretKey"
  description = "IAM user secret token access metric"
}

variable "environment" {
  type        = string
  default     = "tute-production"
  description = "Resource management tag tracking header"
}

