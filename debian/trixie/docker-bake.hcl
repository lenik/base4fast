variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image", "base-image-slim", "base-image-loong64", "base-image-slim-loong64"]
}

target "base-image" {
  network = "host"
  name = "base-image-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  args = {
    BASE_IMAGE = "debian:trixie"
  }
  tags = [
    "b4f-debian:trixie",
    "b4f-debian:trixie-${arch}",
    "b4f-debian:trixie-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:trixie-slim"
  }
  tags = [
    "b4f-debian:trixie-slim",
    "b4f-debian:trixie-slim-${arch}",
    "b4f-debian:trixie-slim-${VERSION}-${arch}",
  ]
}

# Real loong64 trixie from https://github.com/loong64/docker-library
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:trixie"
    DISTRO_SPEC = "debian:trixie"
  }
  tags = [
    "b4f-debian:trixie-loong64",
    "b4f-debian:trixie-${VERSION}-loong64",
  ]
}

target "base-image-slim-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:trixie-slim"
    DISTRO_SPEC = "debian:trixie"
  }
  tags = [
    "b4f-debian:trixie-slim-loong64",
    "b4f-debian:trixie-slim-${VERSION}-loong64",
  ]
}
