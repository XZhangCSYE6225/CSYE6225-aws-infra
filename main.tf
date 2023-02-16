module "mynetwork" {
  source   = "./module/network"
  vpc_cidr = var.cidr_block
  region   = var.vpc_region
  vpc_name = var.name
  profile  = var.profile
}