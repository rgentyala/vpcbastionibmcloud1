module "vpc" {
  source        = "./modules/vpc"
  ZONE          = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  VPC           = var.VPC
  SUBNET        = var.SUBNET
  count         = (var.VPC_EXISTS == "no" && var.SUBNET_EXISTS == "no" ? 1 : 0)
}

module "vpc-subnet" {
  depends_on = [module.vpc]
  source     = "./modules/vpc/subnet"
  ZONE       = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  VPC        = var.VPC
  SUBNET     = var.SUBNET
  HOSTNAME      = var.HOSTNAME
  count      = (var.SUBNET_EXISTS == "no" ? 1 : 0)
}

module "vpc-security-group" {
  depends_on  = [module.vpc-subnet]
  source        = "./modules/vpc/security-group"
  ZONE          = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  VPC           = var.VPC
  SUBNET        = var.SUBNET
  HOSTNAME      = var.HOSTNAME
}

module "volumes" {
  source      = "./modules/volumes"
  depends_on  = [module.vpc , module.vpc-subnet]
  ZONE        = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  HOSTNAME    = var.HOSTNAME
  SUBNET      = var.SUBNET
  VOL_PROFILE = "custom"
  VOL_IOPS    = "3000"
  VOL1        = var.VOL1
}

module "custom-ssh" {
  depends_on  = [module.vpc, module.vpc-subnet]
  source     = "./modules/vpc/security-group/custom-inbound-ssh"
  ZONE       = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  VPC        = var.VPC
  SUBNET     = var.SUBNET
  HOSTNAME    = var.HOSTNAME
  SSH-SOURCE-IP-CIDR-ACCESS = var.SSH-SOURCE-IP-CIDR-ACCESS
  count      = (var.ADD-SOURCE-IP-CIDR == "yes" ? 1 : 0)
}

module "vsi" {
  source        = "./modules/vsi"
  depends_on    = [ module.vpc , module.vpc-subnet , module.vpc-security-group , module.volumes ]
  ZONE          = var.ZONE
  RESOURCE_GROUP = var.RESOURCE_GROUP
  VPC           = var.VPC
  SUBNET        = var.SUBNET
  HOSTNAME      = var.HOSTNAME
  PROFILE       = var.PROFILE
  IMAGE         = var.IMAGE
  SSH_KEYS      = var.SSH_KEYS
  sg-ssh = one(module.custom-ssh[*].sg-ssh)
  securitygroup = one(module.vpc-security-group[*].securitygroup)
  VOLUMES_LIST  = module.volumes.volumes_list
}

module "install-prereq" {
  source     = "./modules/install-prereq"
  depends_on = [module.vsi]
  IP              = module.vsi.FLOATING-IP
  private_ssh_key = var.private_ssh_key
}
