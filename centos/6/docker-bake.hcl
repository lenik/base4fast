variable "VERSION" {
  default = "2.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  contexts = {
    host_opt = "/opt"
  }
  tags = [
    "base4fast:centos-6",
    "base4fast:centos-6-${VERSION}"
  ]
}
