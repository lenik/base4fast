variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  network = "host"
  tags = [
    "b4f-centos:6",
    "b4f-centos:6-amd64",
    "b4f-centos:6-${VERSION}-amd64",
  ]
}
