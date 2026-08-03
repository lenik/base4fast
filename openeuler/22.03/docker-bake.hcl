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
    BASE_IMAGE = "openeuler/openeuler:22.03"
    DISTRO_SPEC = "openeuler:22.03"
  }
  tags = [
    "b4f-openeuler:22.03",
    "b4f-openeuler:22.03-${arch}",
    "b4f-openeuler:22.03-${VERSION}-${arch}",
  ]
}

# Hub has no linux/loong64 for 22.03 — import docker_img first:
#   curl -LO https://mirrors.tuna.tsinghua.edu.cn/openeuler/openEuler-22.03-LTS/docker_img/loongarch64/openEuler-docker.loongarch64.tar.xz
#   docker load -i openEuler-docker.loongarch64.tar.xz
#   docker tag <loaded> openeuler/openeuler:22.03-loong64
target "base-image-loong64" {
  network = "host"
  platforms = ["linux/loong64"]
  args = {
    BASE_IMAGE = "openeuler/openeuler:22.03-loong64"
    DISTRO_SPEC = "openeuler:22.03"
  }
  tags = [
    "b4f-openeuler:22.03-loong64",
    "b4f-openeuler:22.03-${VERSION}-loong64",
  ]
}
