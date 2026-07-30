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
    "base4fast:ubuntu-xenial",
    "base4fast:ubuntu-xenial-${VERSION}",
    "base4fast:ubuntu-16.04",
    "base4fast:ubuntu-16.04-${VERSION}"
  ]
}
