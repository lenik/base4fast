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
    BASE_IMAGE = "debian:buster"
  }
  tags = [
    "b4f-debian:buster",
    "b4f-debian:buster-${arch}",
    "b4f-debian:buster-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:buster-slim"
  }
  tags = [
    "b4f-debian:buster-slim",
    "b4f-debian:buster-slim-${arch}",
    "b4f-debian:buster-slim-${VERSION}-${arch}",
  ]
}
