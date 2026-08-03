variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  network = "host"
  name = "base-image-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  tags = [
    "b4f-centos:s9",
    "b4f-centos:s9-${arch}",
    "b4f-centos:s9-${VERSION}-${arch}",
  ]
}
