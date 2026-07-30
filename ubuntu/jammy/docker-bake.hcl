variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  contexts = {
    host_opt = "/opt"
  }
  tags = [
    "base4fast:ubuntu-jammy",
    "base4fast:ubuntu-jammy-${VERSION}",
    "base4fast:ubuntu-22.04",
    "base4fast:ubuntu-22.04-${VERSION}"
  ]
}
