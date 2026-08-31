# frozen_string_literal: true

require "test_helper"

class LogParserTest < ActiveSupport::TestCase
  test "parses act steps, successes, failures, and lines" do
    raw_logs = <<~LOGS
      [CI/test] ⭐ Run Set up job
      [CI/test]   🐳  docker pull image=ruby:3.4
      [CI/test]   ✅  Success - Set up job
      [CI/test] ⭐ Run Run Tests
      | 🚀 Running test suite...
      | Finished in 0.3s
      [CI/test]   ✅  Success - Run Tests
      [CI/test] 🏁  Job succeeded
    LOGS

    steps = SolidRun::LogParser.parse(raw_logs)

    assert_equal 2, steps.size
    assert_equal "Set up job", steps[0].name
    assert_equal "success", steps[0].status
    assert_includes steps[0].lines.first, "docker pull"

    assert_equal "Run Tests", steps[1].name
    assert_equal "success", steps[1].status
    assert_includes steps[1].lines.first, "Running test suite"
  end
end
