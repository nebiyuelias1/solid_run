# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "securerandom"
require "openssl"
require "yaml"

require_relative "solid_run/git"
require_relative "solid_run/tunnel"
require_relative "solid_run/signature_verifier"
require_relative "solid_run/webhook"
require_relative "solid_run/status_reporter"
require_relative "solid_run/workflow_matcher"
require_relative "solid_run/act_runner"

module SolidRun
  class Error < StandardError; end
end

LocalCI = SolidRun unless defined?(LocalCI)
