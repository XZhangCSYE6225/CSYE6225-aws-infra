module "mynetwork" {
  source             = "./module/network"
  vpc_cidr           = "10.0.0.0/16"
  private_route_cidr = "10.0.0.0/20"
  public_route_cidr  = "10.0.16.0/20"
  region             = "us-east-1"
  vpc_name           = "vpc-1"
}
module "mynetwork2" {
  source             = "./module/network"
  vpc_cidr           = "10.1.0.0/16"
  private_route_cidr = "10.1.0.0/20"
  public_route_cidr  = "10.1.16.0/20"
  region             = "us-east-1"
  vpc_name           = "vpc-2"
}