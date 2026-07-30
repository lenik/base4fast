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
    "base4fast:ubuntu-resolute",
    "base4fast:ubuntu-resolute-${VERSION}",
    "base4fast:ubuntu-26.04",
    "base4fast:ubuntu-26.04-${VERSION}"
  ]
}
