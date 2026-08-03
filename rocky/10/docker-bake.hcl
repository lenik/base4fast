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
  tags = [
    "b4f-rocky:10",
    "b4f-rocky:10-${arch}",
    "b4f-rocky:10-${VERSION}-${arch}",
  ]
}
