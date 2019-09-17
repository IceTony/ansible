data "aws_route53_zone" "srwx-net" {
  name                    = "devops.rebrain.srwx.net."
  private_zone            = false
}

provider "vscale" {
  token                   = "my_vscale_token"
}

provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "~/.aws/credentials"
}

resource "vscale_ssh_key" "icetony" {
  name                    = "icetony.ssh.key"
  key                     = "${file("~/.ssh/id_rsa.pub")}"
}

resource "vscale_ssh_key" "rebrain" {
  name                    = "rebrain.ssh.pub.key"
  key                     = "${file("~/.ssh/rebrain_ssh.pub")}"
}

resource "vscale_scalet" "icetony_nginx_frontend" {
  name                    = "icetony_nginx_frontend"
  location                = "msk0"
  make_from               = "ubuntu_18.04_64_001_master"
  rplan                   = "medium"
  ssh_keys                = ["${vscale_ssh_key.icetony.id}", "${vscale_ssh_key.rebrain.id}"]
}

resource "vscale_scalet" "icetony_nginx_backend" {
  name                    = "icetony_nginx_backend"
  location                = "msk0"
  make_from               = "centos_7_64_001_master"
  rplan                   = "medium"
  ssh_keys                = ["${vscale_ssh_key.icetony.id}", "${vscale_ssh_key.rebrain.id}"]
}

resource "aws_route53_record" "icetony_nginx_frontend_dns" {
  zone_id                 = "${data.aws_route53_zone.srwx-net.zone_id}"
  name                    = "icetony-site1.${data.aws_route53_zone.srwx-net.name}"
  type                    = "A"
  ttl                     = "300"
  records                 = ["${vscale_scalet.icetony_nginx_frontend.public_address}"]
}

resource "aws_route53_record" "icetony_nginx_backend_dns" {
  zone_id                 = "${data.aws_route53_zone.srwx-net.zone_id}"
  name                    = "icetony-site2.${data.aws_route53_zone.srwx-net.name}"
  type                    = "A"
  ttl                     = "300"
  records                 = ["${vscale_scalet.icetony_nginx_backend.public_address}"]
}

resource "local_file" "frontend_inventory" {
    content               = "[load_balancer]\n${aws_route53_record.icetony_nginx_frontend_dns.name}"
    filename              = "${path.module}/frontend.ini"

    provisioner "local-exec" {
    command = <<EOT
      sleep 30;
      export ANSIBLE_HOST_KEY_CHECKING=False;
      ansible-playbook -i frontend.ini ../plays/nginx_load_balancer.yml --extra-vars '{"nginx_backend_address":"${aws_route53_record.icetony_nginx_backend_dns.name}"}'
    EOT
  }
}

resource "local_file" "backend_inventory" {
    content               = "[nginx]\n${aws_route53_record.icetony_nginx_backend_dns.name}"
    filename              = "${path.module}/backend.ini"

    provisioner "local-exec" {
    command = <<EOT
      sleep 30;
      export ANSIBLE_HOST_KEY_CHECKING=False;
      ansible-playbook -i backend.ini ../plays/nginx.yml
    EOT
  }
}
