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
    BASE_IMAGE = "ubuntu:noble"
  }
  tags = [
    "b4f-ubuntu:noble",
    "b4f-ubuntu:noble-${arch}",
    "b4f-ubuntu:noble-${VERSION}-${arch}",
    "b4f-ubuntu:24.04",
    "b4f-ubuntu:24.04-${arch}",
    "b4f-ubuntu:24.04-${VERSION}-${arch}",
  ]
}
