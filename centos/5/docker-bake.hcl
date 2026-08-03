variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  network = "host"
  tags = [
    "b4f-centos:5",
    "b4f-centos:5-amd64",
    "b4f-centos:5-${VERSION}-amd64",
  ]
}
