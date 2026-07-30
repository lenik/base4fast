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
    "base4fast:ubuntu-focal",
    "base4fast:ubuntu-focal-${VERSION}",
    "base4fast:ubuntu-20.04",
    "base4fast:ubuntu-20.04-${VERSION}"
  ]
}
