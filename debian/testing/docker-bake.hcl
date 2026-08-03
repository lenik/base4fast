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
    BASE_IMAGE = "debian:testing"
    DISTRO_SPEC = "debian:testing"
  }
  tags = [
    "b4f-debian:testing",
    "b4f-debian:testing-${arch}",
    "b4f-debian:testing-${VERSION}-${arch}",
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
    BASE_IMAGE = "debian:testing-slim"
    DISTRO_SPEC = "debian:testing"
  }
  tags = [
    "b4f-debian:testing-slim",
    "b4f-debian:testing-slim-${arch}",
    "b4f-debian:testing-slim-${VERSION}-${arch}",
  ]
}

# Floating testing ≈ forky; loong64 bases from ghcr.io/loong64/debian.
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:forky"
    DISTRO_SPEC = "debian:testing"
    RUNTIME_PKGS = "libcurl4t64 libglib2.0-0t64 libicu78 zlib1g"
  }
  tags = [
    "b4f-debian:testing-loong64",
    "b4f-debian:testing-${VERSION}-loong64",
  ]
}

target "base-image-slim-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "ghcr.io/loong64/debian:forky-slim"
    DISTRO_SPEC = "debian:testing"
    RUNTIME_PKGS = "libcurl4t64 libglib2.0-0t64 libicu78 zlib1g"
  }
  tags = [
    "b4f-debian:testing-slim-loong64",
    "b4f-debian:testing-slim-${VERSION}-loong64",
  ]
}
