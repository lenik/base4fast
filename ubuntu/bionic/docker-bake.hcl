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
    "base4fast:ubuntu-bionic",
    "base4fast:ubuntu-bionic-${VERSION}",
    "base4fast:ubuntu-18.04",
    "base4fast:ubuntu-18.04-${VERSION}"
  ]
}
