variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image", "base-image-slim"]
}

target "base-image" {
  network = "host"
  name = "base-image-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  args = {
    BASE_IMAGE = "debian:stretch"
  }
  tags = [
    "b4f-debian:stretch",
    "b4f-debian:stretch-${arch}",
    "b4f-debian:stretch-${VERSION}-${arch}",
  ]
}

target "base-image-slim" {
  network = "host"
  name = "base-image-slim-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  args = {
    BASE_IMAGE = "debian:stretch-slim"
  }
  tags = [
    "b4f-debian:stretch-slim",
    "b4f-debian:stretch-slim-${arch}",
    "b4f-debian:stretch-slim-${VERSION}-${arch}",
  ]
}
