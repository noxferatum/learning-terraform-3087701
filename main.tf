data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

data "aws_vpc" "default" {
  default = true
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.enviorment.name
  cidr = "${var.enviorment.network_prefix}.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  public_subnets  = ["${var.enviorment.network_prefix}.101.0/24", "${var.enviorment.network_prefix}.102.0/24", "${var.enviorment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = var.enviorment.name
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.0"
  
  
  name = "${var.enviorment.name}-web"
  min_size = var.asg_min_size
  max_size = var.asg_max_size

  vpc_zone_identifier = module.web_vpc.public_subnets
  target_group_arns   = module.web_alb.target_group_arns
  security_groups     = [module.web_sg.security_group_id]

  image_id     = data.aws_ami.app_ami.id
  instance_type = var.instance_type
}

module "web_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "${var.enviorment.name}-web-alb"

  load_balancer_type = "application"

  vpc_id          = module.web_vpc.vpc_id
  subnets         = module.web_vpc.public_subnets
  security_groups = [module.web_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "${var.enviorment.name}"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "${var.enviorment.name}"
  }
}

module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name    = "${var.enviorment.name}-web"

  vpc_id = module.web_vpc.vpc_id
    
  ingress_rules       = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}