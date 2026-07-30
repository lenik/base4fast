variable "VERSION" {
  default = "1.0"
}

group "default" {
  targets = ["base-image"]
}

target "base-image" {
  contexts = {
    host_opt = "/opt"
    leap42_repo = "../../scripts/build4-bins/leap42.1-repo"
  }
  tags = [
    "base4fast:sles-12.1",
    "base4fast:sles-12.1-${VERSION}"
  ]
}
