provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

data aws_vpc "default_vpc" {
  default = true
}

data "aws_ami" "centos" {
  most_recent = true

  filter {
    name   = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }

  owners = ["679593333241"]
}

data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"] # Canonical
}

resource aws_security_group "sg_ec2_common" {
  name   = "ec2-common"
  vpc_id = "${data.aws_vpc.default_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Nescessary
    cidr_blocks = ["0.0.0.0/0"] # Destination..
  }

  tags {
    Name                              = "ec2-common"
    "kubernetes.io/cluster/openshift" = "owned"
  }
}

resource aws_security_group "sg_ec2_master" {
  name   = "ec2-master"
  vpc_id = "${data.aws_vpc.default_vpc.id}"

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Nescessary
    cidr_blocks = ["0.0.0.0/0"] # Destination..
  }

  tags {
    Name = "ec2-master"
  }
}

resource aws_security_group "sg_ec2_node" {
  name   = "ec2-node"
  vpc_id = "${data.aws_vpc.default_vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Nescessary
    cidr_blocks = ["0.0.0.0/0"] # Destination..
  }

  tags {
    Name = "ec2-node"
  }
}

resource "aws_iam_instance_profile" "k8s_profile" {
  name = "k8s_profile"
  role = "${aws_iam_role.k8s_role.name}"
}

resource "aws_iam_role" "k8s_role" {
  name = "k8s_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "k8s_policy" {
  name = "k8s_policy"
  role = "${aws_iam_role.k8s_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
            "ec2:AttachVolume",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceAttribute",
            "elasticloadbalancing:ConfigureHealthCheck",
            "ec2:DescribeVolumesModifications",
            "elasticloadbalancing:DeleteLoadBalancer",
            "ec2:DeleteVolume",
            "elasticloadbalancing:DescribeLoadBalancers",
            "ec2:DescribeVolumeStatus",
            "ec2:CreateSecurityGroup",
            "ec2:DescribeVolumes",
            "ec2:DescribeRouteTables",
            "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
            "ec2:DescribeInstanceStatus",
            "ec2:DetachVolume",
            "elasticloadbalancing:CreateLoadBalancer",
            "ec2:CreateTags",
            "elasticloadbalancing:DescribeTags",
            "ec2:DescribeInstanceCreditSpecifications",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVolumeAttribute",
            "ec2:CreateVolume",
            "elasticloadbalancing:CreateLoadBalancerListeners",
            "ec2:RevokeSecurityGroupIngress",
            "elasticloadbalancing:DescribeLoadBalancerAttributes",
            "ec2:DeleteSecurityGroup",
            "elasticloadbalancing:DeleteLoadBalancerListeners",
            "ec2:DescribeSubnets",
            "elasticloadbalancing:ModifyLoadBalancerAttributes"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource aws_spot_instance_request "master" {
  depends_on             = ["aws_iam_instance_profile.k8s_profile"]
  count                  = "${var.master_number}"
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.master_ec2_type}"
  vpc_security_group_ids = ["${aws_security_group.sg_ec2_common.id}", "${aws_security_group.sg_ec2_master.id}"]
  key_name               = "${var.key_name}"
  spot_price             = "${var.master_spot_price}"
  availability_zone      = "${var.availability_zone}"
  wait_for_fulfillment   = true
  iam_instance_profile   = "${aws_iam_instance_profile.k8s_profile.name}"

  root_block_device {
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/xvdb"
    volume_size           = 100
    volume_type           = "gp2"
    delete_on_termination = true
  }

#  ebs_block_device {
#    device_name           = "/dev/xvdc"
#    volume_size           = 100
#    volume_type           = "gp2"
#    delete_on_termination = true
#  }

  tags {
    Name                              = "master-${count.index}"
    Role                              = "master"
    "kubernetes.io/cluster/openshift" = "owned"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file(var.private_key_path)}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    source      = "provision.sh"
    destination = "/home/ubuntu/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/provision.sh ${var.access_key} ${var.secret_key} ${var.region} ${self.id} ${self.spot_instance_id}",
    ]
  }
}

resource aws_spot_instance_request "node" {
  count                  = "${var.node_number}"
  depends_on             = ["aws_iam_instance_profile.k8s_profile"]
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.node_ec2_type}"
  vpc_security_group_ids = ["${aws_security_group.sg_ec2_common.id}", "${aws_security_group.sg_ec2_node.id}"]
  key_name               = "${var.key_name}"
  spot_price             = "${var.node_spot_price}"
  availability_zone      = "${var.availability_zone}"
  wait_for_fulfillment   = true
  iam_instance_profile   = "${aws_iam_instance_profile.k8s_profile.name}"
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags {
    Name                              = "node-${count.index}"
    Role                              = "node"
    "kubernetes.io/cluster/openshift" = "owned"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file(var.private_key_path)}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    source      = "provision.sh"
    destination = "/home/ubuntu/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/provision.sh ${var.access_key} ${var.secret_key} ${var.region} ${self.id} ${self.spot_instance_id}",
    ]
  }
}

resource aws_spot_instance_request "bastion" {
  depends_on             = ["aws_iam_instance_profile.k8s_profile"]
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.small"
  vpc_security_group_ids = ["${aws_security_group.sg_ec2_common.id}"]
  key_name               = "${var.key_name}"
  spot_price             = "0.02"
  availability_zone      = "${var.availability_zone}"
  wait_for_fulfillment   = true
  iam_instance_profile   = "${aws_iam_instance_profile.k8s_profile.name}"

  root_block_device {
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags {
    Name                              = "bastion-${count.index}"
    Role                              = "bastion"
    "kubernetes.io/cluster/openshift" = "owned"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file(var.private_key_path)}"
    host        = "${self.public_ip}"
  }

  provisioner "file" {
    source      = "provision.sh"
    destination = "/home/ubuntu/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/provision.sh ${var.access_key} ${var.secret_key} ${var.region} ${self.id} ${self.spot_instance_id}",
    ]
  }
}

data "aws_route53_zone" "expllore" {
  name = "expllore.me.uk."
}

resource "aws_route53_record" "k8s_console" {
  zone_id = "${data.aws_route53_zone.expllore.zone_id}"
  name    = "k8s.${data.aws_route53_zone.expllore.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_spot_instance_request.master.0.public_ip}"]
}

resource "aws_route53_record" "k8s_server" {
  zone_id = "${data.aws_route53_zone.expllore.zone_id}"
  name    = "kubernetes.default.svc.k8s.${data.aws_route53_zone.expllore.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_spot_instance_request.master.0.public_ip}"]
}
