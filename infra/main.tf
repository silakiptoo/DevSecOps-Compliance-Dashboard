
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "devsecops" {
  id = "vpc-0c8433dba6c6dc121"
}

output "vpc_id" {
  value = data.aws_vpc.devsecops.id
}

output "vpc_cidr_block" {
  value = data.aws_vpc.devsecops.cidr_block
}
