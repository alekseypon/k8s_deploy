output "master-public-ip" {
  value = "${aws_spot_instance_request.master.*.public_ip}"
}

output "master-private-ip" {
  value = "${aws_spot_instance_request.master.*.private_ip}"
}

output "node-public-ip" {
  value = "${aws_spot_instance_request.node.*.public_ip}"
}

output "node-private-ip" {
  value = "${aws_spot_instance_request.node.*.private_ip}"
}
