variable "region" {
  default = "eu-west-1"
}

variable "name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "instance_type" {
  default = "t3.medium"
}

variable "nr_key" {
  sensitive = true
}

variable "nr_acc_id" {
  sensitive = true
}

variable "pub_subnet1_cidr" {
  type = string
}

variable "pub_subnet2_cidr" {
  type = string
}

variable "priv_subnet1_cidr" {
  type = string
}

variable "priv_subnet2_cidr" {
  type = string
}

variable "pub_subnet1_az" {
  type = string
}

variable "pub_subnet2_az" {
  type = string
}

variable "priv_subnet1_az" {
  type = string
}

variable "priv_subnet2_az" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "vault_sg_cidr" {
  description = "CIDR block of the Vault subnet or host"
  type        = string
}

variable "vault_vpc_cidr" {
  description = "CIDR block of the Vault VPC"
  type        = string
}
