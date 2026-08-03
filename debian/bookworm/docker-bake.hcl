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
    BASE_IMAGE = "debian:bookworm"
  }
  tags = [
    "b4f-debian:bookworm",
    "b4f-debian:bookworm-${arch}",
    "b4f-debian:bookworm-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:bookworm-slim"
  }
  tags = [
    "b4f-debian:bookworm-slim",
    "b4f-debian:bookworm-slim-${arch}",
    "b4f-debian:bookworm-slim-${VERSION}-${arch}",
  ]
}
