variable "region" {
  type = string

}

variable "profile" {
  type    = string
  default = "dev"
}

variable "aval_zone" {
  type    = list(string)
  default = ["d", "e", "f"]
}

variable "length" {
  type    = number
  default = 3
}

variable "vpc_cidr" {
  type = string
}

variable "public_route_cidr" {
  type = string
}

variable "private_route_cidr" {
  type = string
}