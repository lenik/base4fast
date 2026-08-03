variable "VERSION" {
  default = "1.0-snapshot"
}

# Parent may be registry-qualified (pulled on build); output tags stay local.
variable "BASE_IMAGE" {
  default = "183.131.83.99:1244/b4f-rocky:10"
}

group "default" {
  targets = ["rockynode"]
}

target "rockynode" {
  context = "."
  dockerfile = "Dockerfile"
  shm-size = "256m"
  provenance = false
  args = {
    BASE_IMAGE = BASE_IMAGE
    VERSION = VERSION
  }
  tags = [
    "b4f-rockynode:10",
    "b4f-rockynode:10-${VERSION}"
  ]
}
