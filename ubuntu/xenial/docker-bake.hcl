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
    BASE_IMAGE = "ubuntu:xenial"
  }
  tags = [
    "b4f-ubuntu:xenial",
    "b4f-ubuntu:xenial-${arch}",
    "b4f-ubuntu:xenial-${VERSION}-${arch}",
    "b4f-ubuntu:16.04",
    "b4f-ubuntu:16.04-${arch}",
    "b4f-ubuntu:16.04-${VERSION}-${arch}",
  ]
}
