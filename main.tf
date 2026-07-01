module "bastion" {
  source = "./modules/bastion"

  name             = var.name
  instance_type    = var.instance_type
  bastion_sg_id    = module.bastion_sg.bastion_sg_id
  bastion_host_id  = module.bastion_sg.bastion_host_id
  bastion_asg_id   = module.bastion_sg.bastion_asg_id
  nexus_ip        = module.nexus.nexus_private_ip
  bucket_name     = "${var.name}-bucket"
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet1_id

  key_pair_name = var.key_pair_name

  private_key = var.private_key

  nr_key    = var.nr_key
  nr_acc_id = var.nr_acc_id

  region = var.region
}

module "database" {
  source = "./modules/database"

  name = var.name

  vpc_id = module.vpc.vpc_id

  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id

  vault_sg_id = module.vault.vault_sg_id
}

module "nexus" {
  source = "./modules/nexus"

  name = var.name

  instance_type = var.instance_type

  domain_name = var.domain_name

  vpc_id = module.vpc.vpc_id

  public_subnet1_id = module.vpc.public_subnet1_id
  public_subnet2_id = module.vpc.public_subnet2_id

  bastion_sg_id = module.bastion.bastion_sg_id

  key_pair_name = var.key_pair_name

  zone_id = module.route53.zone_id

  acm_certificate_arn = module.acm.acm_arn
}

module "sonarqube" {
  source = "./modules/sonarqube"

  name = var.name

  domain_name = var.domain_name

  instance_type = var.instance_type

  vpc_id = module.vpc.vpc_id

  public_subnet_id  = module.vpc.public_subnet1_id
  public_subnet1_id = module.vpc.public_subnet1_id
  public_subnet2_id = module.vpc.public_subnet2_id

  bastion_sg_id = module.bastion.bastion_sg_id

  key_pair_name = var.key_pair_name

  db_host     = module.database.db_endpoint
  db_name     = module.database.db_name
  db_user     = module.database.db_username
  db_password = module.database.db_password

  acm_certificate_arn = module.acm.acm_arn

  zone_id = module.route53.zone_id
}

module "ansible" {
  source = "./modules/ansible"

  name = var.name

  instance_type = var.instance_type

  vpc_id = module.vpc.vpc_id

  public_subnet_id = module.vpc.public_subnet1_id

  bastion_sg_id = module.bastion.bastion_sg_id

  key_pair_name = var.key_pair_name

  nexus_ip = module.nexus.nexus_private_ip

  bucket_name = "${var.name}-bucket"

  private_key = var.private_key

  nr_key    = var.nr_key
  nr_acc_id = var.nr_acc_id
}

module "prod" {
  source = "./modules/prod"

  name = var.name

  vpc_id = module.vpc.vpc_id

  private_subnet1_id = module.vpc.private_subnet1_id

  bastion_sg_id = module.bastion.bastion_sg_id

  key_pair_name = var.key_pair_name

  nexus_ip = module.nexus.nexus_private_ip

  nr_key    = var.nr_key
  nr_acc_id = var.nr_acc_id
}

module "stage" {
  source = "./modules/stage"

  name = var.name

  vpc_id = module.vpc.vpc_id

  private_subnet1_id = module.vpc.private_subnet1_id

  bastion_sg_id = module.bastion.bastion_sg_id

  key_pair_name = var.key_pair_name

  nexus_ip = module.nexus.nexus_private_ip

  nr_key    = var.nr_key
  nr_acc_id = var.nr_acc_id
}

module "vpc" {
  source = "./modules/vpc"

  name = var.name
  cidr_block = var.vpc_cidr_block
  region = var.region
  pub_subnet1_cidr = var.pub_subnet1_cidr       
  pub_subnet1_az = var.pub_subnet1_az
  pub_subnet2_cidr = var.pub_subnet2_cidr
  pub_subnet2_az = var.pub_subnet2_az
  priv_subnet1_cidr = var.priv_subnet1_cidr
  priv_subnet1_az = var.priv_subnet1_az
  priv_subnet2_cidr = var.priv_subnet2_cidr
  priv_subnet2_az = var.priv_subnet2_az
  availability_zone = var.availability_zone

}

