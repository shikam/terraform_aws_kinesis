variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default = "10.135.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  default = "10.135.0.0/22"
}

variable "key_path" {
  description = "SSH Public Key path"
  default = "public_key"
}
