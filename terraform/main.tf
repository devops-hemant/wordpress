

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

data "aws_kms_secrets" "cred" {
  secret {
    name    = "db"
    payload = file("${path.module}/cred.yml.encrypted")
  }
}

locals {
  db_creds = yamldecode(data.aws_kms_secrets.cred.plaintext["db"])
}

locals {
  cluster_name = "wordpress-eks-cluster"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "wordpress-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.25"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t2.micro"]

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t2.micro"]

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }
}
    

# data "aws_iam_policy" "ebs_csi_policy" {
#   arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }

# module "irsa-ebs-csi" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "4.7.0"

#   create_role                   = true
#   role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
#   provider_url                  = module.eks.oidc_provider
#   role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
#   oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
# }

# resource "aws_eks_addon" "ebs-csi" {
#   cluster_name             = module.eks.cluster_name
#   addon_name               = "aws-ebs-csi-driver"
#   addon_version            = "v1.5.2-eksbuild.1"
#   service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
#   tags = {
#     "eks_addon" = "ebs-csi"
#     "terraform" = "true"
#   }
# }

resource "aws_db_subnet_group" "default" {
  name       = "main_group"
  subnet_ids = module.vpc.public_subnets
}

resource "aws_security_group" "allow_db_ports" {
  name        = "allow_db_ports"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "3306 from VPC"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  tags = {
    Name = "allow_db_ports"
  }
}


resource "aws_db_instance" "wordpressrds" {
  allocated_storage    = 10
  db_name              = "wordpress"
  engine               = "mysql"
  engine_version       = "8.0.28"
  instance_class       = "db.t2.micro"
  username             = local.db_creds.username
  password             = local.db_creds.password
  skip_final_snapshot  = true
  vpc_security_group_ids = [ aws_security_group.allow_db_ports.id ]
  db_subnet_group_name = aws_db_subnet_group.default.name
  tags = {
    "Name" = "myrds"
  }
}

resource "aws_efs_file_system" "efs-volume" {
  creation_token = "my-efs"
  encrypted = true

  tags = {
    Name = "MyEFS"
  }
}


