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
    "base4fast:bullseye",
    "base4fast:bullseye-${VERSION}"
  ]
}
