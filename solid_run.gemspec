# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "solid_run"
  spec.version       = "0.1.0"
  spec.authors       = ["Nebiyu Talefe"]
  spec.email         = ["nebiyuelias1@gmail.com"]
  spec.summary       = "Local GitHub Actions CI runner powered by Rails 8, Solid Queue, and act"
  spec.description   = "Automatically spins up a Cloudflare Tunnel, registers GitHub webhooks, queues jobs in Solid Queue, runs act in Docker, and provides a real-time web dashboard."
  spec.homepage      = "https://github.com/nebiyuelias1/solid_run"
  spec.license       = "MIT"

  spec.files         = Dir["{app,bin,config,db,lib,public}/**/*", "Rakefile", "README.md", "Gemfile", "config.ru"]
  spec.bindir        = "bin"
  spec.executables   = ["solid_run"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.1.0"
end
