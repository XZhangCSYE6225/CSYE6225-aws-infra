variable "region" {
  type = string

}

variable "profile" {
  type = string
}

variable "vpc_name" {
  type = string
}


variable "length" {
  type    = number
  default = 3
}

variable "vpc_cidr" {
  type = string
}
