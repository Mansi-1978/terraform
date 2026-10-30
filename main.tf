provider "aws"{
    region = "ap-south-1"
}

#AWSEksclusterpolicy
resource "aws_iam_role" "cluster" {
  name = "eks-cluster-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

data "aws_vpc" "default"{
    default = true
}

data "aws_subnets" "default"{
    filter{
        name ="vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

#aws cluster
resource "aws_eks_cluster" "cluster"{

    name = "cluster"

    access_config{
        authentication_mode =  "API"
    }

    role_arn = aws_iam_role.cluster.arn
    version = "1.36"

    vpc_config{
      subnet_ids = data.aws_subnets.default.ids
    }

    depends_on = [ aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy ]


}

#node group policies
resource "aws_iam_role" "node-group" {
  name = "node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "workerNode-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "CNI-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "EC2ContainerRegisteryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node-group.name
}

#node groups
resource "aws_eks_node_group" "node-group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.node-group.arn
  subnet_ids      = data.aws_subnets.default.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

   instance_types = ["c7i-flex.large"]

  ami_type = "AL2023_x86_64_STANDARD"   

  disk_size = 20

  capacity_type = "ON_DEMAND"

  tags = {
    Name = "my-cluster-nodegroup"
  }


  depends_on = [
    aws_iam_role_policy_attachment.workerNode-policy,
    aws_iam_role_policy_attachment.CNI-policy,
    aws_iam_role_policy_attachment.EC2ContainerRegisteryReadOnly,
  ]
}


