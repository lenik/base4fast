variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image", "base-image-loong64"]
}

target "base-image" {
  network = "host"
  name = "base-image-${arch}"
  matrix = {
    arch = ["amd64", "arm64"]
  }
  platforms = ["linux/${arch}"]
  args = {
    BASE_IMAGE = "openeuler/openeuler:24.03"
    DISTRO_SPEC = "openeuler:24.03"
  }
  tags = [
    "b4f-openeuler:24.03",
    "b4f-openeuler:24.03-${arch}",
    "b4f-openeuler:24.03-${VERSION}-${arch}",
  ]
}

# Official Hub multi-arch includes linux/loong64; ghcr.io/loong64/openeuler:24 is an alternate.
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "openeuler/openeuler:24.03"
    DISTRO_SPEC = "openeuler:24.03"
  }
  tags = [
    "b4f-openeuler:24.03-loong64",
    "b4f-openeuler:24.03-${VERSION}-loong64",
  ]
}
