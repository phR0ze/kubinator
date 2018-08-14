Gem::Specification.new do |spec|
  spec.name        = 'kubinator'
  spec.version     = '0.1.27'
  spec.summary     = "Deployment automation for Kubernetes"
  spec.authors     = ["Patrick Crummett"]
  spec.homepage    = 'https://github.com/phR0ze/kubinator'
  spec.license     = 'MIT'

  # Runtime dependencies
  spec.add_dependency('nub', '~> 0.0.103')
  spec.add_dependency('filesize', '~> 0.1.1')
  spec.add_dependency('net-ssh', '~> 5.0.2')
  spec.add_dependency('net-scp', '~> 1.2.1')

  # Development dependencies
  spec.add_development_dependency('minitest', '~> 5.11.3')
  spec.add_development_dependency('coveralls', '~> 0.8.22')
  spec.add_development_dependency('bundler', '~> 1.16')
  spec.add_development_dependency('rake', '~> 12.0')
end
# vim: ft=ruby:ts=2:sw=2:sts=2
