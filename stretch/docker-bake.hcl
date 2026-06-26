variable "VERSION" {
  default = "2.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  tags = [
    "base4fast:stretch",
    "base4fast:stretch-${VERSION}"
  ]
}
