module "mynetwork" {
  source             = "./module/network"
  vpc_cidr           = "10.0.0.0/16"
  private_route_cidr = "10.0.0.0/20"
  public_route_cidr  = "10.0.16.0/20"
  region             = "us-east-1"
}