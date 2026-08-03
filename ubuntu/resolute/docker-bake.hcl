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
    BASE_IMAGE = "ubuntu:resolute"
  }
  tags = [
    "b4f-ubuntu:resolute",
    "b4f-ubuntu:resolute-${arch}",
    "b4f-ubuntu:resolute-${VERSION}-${arch}",
    "b4f-ubuntu:26.04",
    "b4f-ubuntu:26.04-${arch}",
    "b4f-ubuntu:26.04-${VERSION}-${arch}",
  ]
}
