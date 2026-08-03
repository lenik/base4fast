variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image", "base-image-slim", "base-image-loong64"]
}

target "base-image" {
  network = "host"
  name = "base-image-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  args = {
    BASE_IMAGE = "debian:sid"
    DISTRO_SPEC = "debian:sid"
    # sid has no -updates/-security/-backports suites
    LRM_BWSEL_OPTS = "--no-updates --no-security --no-backports --no-src"
    RUNTIME_PKGS = "libcurl4t64 libglib2.0-0t64 libicu78 zlib1g"
  }
  tags = [
    "b4f-debian:sid",
    "b4f-debian:sid-${arch}",
    "b4f-debian:sid-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:sid-slim"
    DISTRO_SPEC = "debian:sid"
    LRM_BWSEL_OPTS = "--no-updates --no-security --no-backports --no-src"
    RUNTIME_PKGS = "libcurl4t64 libglib2.0-0t64 libicu78 zlib1g"
  }
  tags = [
    "b4f-debian:sid-slim",
    "b4f-debian:sid-slim-${arch}",
    "b4f-debian:sid-slim-${VERSION}-${arch}",
  ]
}

# Local debootstrap import (no official library sid-loong64; ghcr has forky/trixie).
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "debian:sid-loong64"
    DISTRO_SPEC = "debian:sid"
    LRM_BWSEL_OPTS = "--no-updates --no-security --no-backports --no-src"
    RUNTIME_PKGS = "libcurl4t64 libglib2.0-0t64 libicu78 zlib1g"
  }
  tags = [
    "b4f-debian:sid-loong64",
    "b4f-debian:sid-${VERSION}-loong64",
  ]
}
