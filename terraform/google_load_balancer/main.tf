data "aws_route53_zone" "srwx-net" {
  name                    = "devops.rebrain.srwx.net."
  private_zone            = false
}

provider "google" {
  credentials = "${file("~/.tokens/google_cloud.json")}"
  project     = "rebrain"
  region      = "us-central1"
  zone        = "us-central1-a"
}

provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "~/.aws/credentials"
}

resource "google_compute_instance" "icetony_vm" {
  name         = "icetony"
  machine_type = "custom-2-4096"

  boot_disk {
    initialize_params {
      image    = "ubuntu-os-cloud/ubuntu-1804-lts"
      size     = "20"
    }
  }

  network_interface {
    network    = "default"
    access_config {
    }
  }

  metadata     = {
    ssh-keys   = "root:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "google_compute_instance_group" "icetony_vm_group" {
    name       = "icetony-vm-group"
    zone       = "us-central1-a"
    instances  = ["${google_compute_instance.icetony_vm.self_link}"]
    
    named_port {
      name     = "http"
      port     = "80"
  }
}

resource "google_compute_backend_service" "icetony_bs" {
  name            = "icetony-bs"
  port_name       = "http"
  protocol        = "HTTP"
  timeout_sec     = "10"
  backend {
    group         = "${google_compute_instance_group.icetony_vm_group.self_link}"
  }
  health_checks   = ["${google_compute_http_health_check.icetony_health_check.self_link}"]
}

resource "google_compute_global_address" "ext_ip" {
  name            = "icetony-ip"
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "icetony-forwarding-rule"
  target     = "${google_compute_target_http_proxy.default.self_link}"
  ip_address = "${google_compute_global_address.ext_ip.address}"
  port_range = "80"
  depends_on = ["google_compute_global_address.ext_ip"]
}

resource "google_compute_target_http_proxy" "default" {
  name    = "icetony-http-proxy"
  url_map = "${google_compute_url_map.default.self_link}"
}

resource "google_compute_url_map" "default" {
  name            = "icetony-url-map"
  default_service = "${google_compute_backend_service.icetony_bs.self_link}"
}

resource "aws_route53_record" "icetony_frontend_dns" {
  zone_id                 = "${data.aws_route53_zone.srwx-net.zone_id}"
  name                    = "icetony-frontend.${data.aws_route53_zone.srwx-net.name}"
  type                    = "A"
  ttl                     = "300"
  records                 = ["${google_compute_global_address.ext_ip.address}"]
}

resource "aws_route53_record" "icetony_backend_dns" {
  zone_id                 = "${data.aws_route53_zone.srwx-net.zone_id}"
  name                    = "icetony-backend.${data.aws_route53_zone.srwx-net.name}"
  type                    = "A"
  ttl                     = "300"
  records                 = ["${join("", google_compute_instance.icetony_vm.*.network_interface.0.access_config.0.nat_ip)}"]
}

resource "google_compute_http_health_check" "icetony_health_check" {
  name         = "icetony-health-check"
  request_path = "/"
}

resource "local_file" "backend_inventory" {
    content               = "[nginx]\n${aws_route53_record.icetony_backend_dns.name}"
    filename              = "${path.module}/backend.ini"

    provisioner "local-exec" {
      command = <<EOT
        sleep 30;
        export ANSIBLE_HOST_KEY_CHECKING=False;
        ansible-playbook -i backend.ini ../../plays/nginx.yml
      EOT
  }
}
