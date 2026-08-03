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
  args = {
    BASE_IMAGE = "ubuntu:focal"
  }
  tags = [
    "b4f-ubuntu:focal",
    "b4f-ubuntu:focal-${arch}",
    "b4f-ubuntu:focal-${VERSION}-${arch}",
    "b4f-ubuntu:20.04",
    "b4f-ubuntu:20.04-${arch}",
    "b4f-ubuntu:20.04-${VERSION}-${arch}",
  ]
}
