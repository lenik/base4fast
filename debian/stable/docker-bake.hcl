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
    BASE_IMAGE = "debian:stable"
    DISTRO_SPEC = "debian:stable"
  }
  tags = [
    "b4f-debian:stable",
    "b4f-debian:stable-${arch}",
    "b4f-debian:stable-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:stable-slim"
    DISTRO_SPEC = "debian:stable"
  }
  tags = [
    "b4f-debian:stable-slim",
    "b4f-debian:stable-slim-${arch}",
    "b4f-debian:stable-slim-${VERSION}-${arch}",
  ]
}

# Floating stable ≈ trixie; loong64 bases from ghcr.io/loong64/debian.
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:trixie"
    DISTRO_SPEC = "debian:stable"
  }
  tags = [
    "b4f-debian:stable-loong64",
    "b4f-debian:stable-${VERSION}-loong64",
  ]
}

target "base-image-slim-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:trixie-slim"
    DISTRO_SPEC = "debian:stable"
  }
  tags = [
    "b4f-debian:stable-slim-loong64",
    "b4f-debian:stable-slim-${VERSION}-loong64",
  ]
}
