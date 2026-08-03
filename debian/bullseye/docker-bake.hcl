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
    BASE_IMAGE = "debian:bullseye"
  }
  tags = [
    "b4f-debian:bullseye",
    "b4f-debian:bullseye-${arch}",
    "b4f-debian:bullseye-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:bullseye-slim"
  }
  tags = [
    "b4f-debian:bullseye-slim",
    "b4f-debian:bullseye-slim-${arch}",
    "b4f-debian:bullseye-slim-${VERSION}-${arch}",
  ]
}
