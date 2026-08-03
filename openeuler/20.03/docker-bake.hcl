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
    BASE_IMAGE = "openeuler/openeuler:20.03"
    DISTRO_SPEC = "openeuler:20.03"
  }
  tags = [
    "b4f-openeuler:20.03",
    "b4f-openeuler:20.03-${arch}",
    "b4f-openeuler:20.03-${VERSION}-${arch}",
  ]
}
