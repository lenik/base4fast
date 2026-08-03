variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  network = "host"
  contexts = {
    leap42_repo = "../../scripts/build4-bins/leap42.1-repo"
  }

  tags = [
    "b4f-sles:12.1",
    "b4f-sles:12.1-amd64",
    "b4f-sles:12.1-${VERSION}-amd64",
  ]
}
