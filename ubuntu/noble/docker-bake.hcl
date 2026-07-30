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
    "base4fast:ubuntu-noble",
    "base4fast:ubuntu-noble-${VERSION}",
    "base4fast:ubuntu-24.04",
    "base4fast:ubuntu-24.04-${VERSION}"
  ]
}
