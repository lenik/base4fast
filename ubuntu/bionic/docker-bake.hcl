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
    BASE_IMAGE = "ubuntu:bionic"
  }
  tags = [
    "b4f-ubuntu:bionic",
    "b4f-ubuntu:bionic-${arch}",
    "b4f-ubuntu:bionic-${VERSION}-${arch}",
    "b4f-ubuntu:18.04",
    "b4f-ubuntu:18.04-${arch}",
    "b4f-ubuntu:18.04-${VERSION}-${arch}",
  ]
}
