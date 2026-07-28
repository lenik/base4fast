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
    "base4fast:bookworm",
    "base4fast:bookworm-${VERSION}"
  ]
}
