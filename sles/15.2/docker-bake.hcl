variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  network = "host"
  tags = [
    "b4f-sles:15.2",
    "b4f-sles:15.2-amd64",
    "b4f-sles:15.2-${VERSION}-amd64",
  ]
}
