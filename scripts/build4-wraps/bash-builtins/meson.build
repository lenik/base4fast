# Minimal dependency provider for bash loadable builtin headers.
# Used when building bas-c inside older distros via build4.
project('bash-builtins', 'c', version: '5.0')

# Match `pkg-config --cflags bash` layout on Debian:
#   -I/usr/include/bash -I/usr/include/bash/builtins -I/usr/include/bash/include
bash_inc = include_directories(
  '/usr/include/bash',
  '/usr/include/bash/include',
  '/usr/include/bash/builtins',
  is_system: true,
)

bash_builtins_dep = declare_dependency(
  include_directories: bash_inc,
  compile_args: ['-DSHELL'],
)

# override_dependency() needs Meson >= 0.54; older consumers use get_variable().
if meson.version().version_compare('>=0.54.0')
  meson.override_dependency('bash-builtins', bash_builtins_dep)
endif

pkg = import('pkgconfig')
pkg.generate(
  name: 'bash-builtins',
  description: 'Bash loadable builtin headers',
  version: meson.project_version(),
)
