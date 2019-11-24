variable "region_name" {
  description = "Region in which the infrastructure will be deployed"
  default     = "us-east-1"
}

variable "public_key_path" {
  description = "Public key path"
  default     = "public_keys/id_rsa.pub"
}

variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default     = "ami-00068cd7555f543d5" # CentOS 7 (free tier)
}

variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "t2.micro"
}

variable "app_port" {
  description = "Port which the application will run"
  default = "80"
}

