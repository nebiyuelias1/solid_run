# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class ActRunnerTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir("local_ci_test_")
    @workflows_dir = File.join(@tmp_dir, ".github", "workflows")
    FileUtils.mkdir_p(@workflows_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_actionable_events
    runner = LocalCI::ActRunner.new(repo_full_name: "test/repo", workflows_dir: @workflows_dir)
    assert runner.actionable?("push")
    assert runner.actionable?("pull_request")
    assert runner.actionable?("workflow_dispatch")
    refute runner.actionable?("ping")
    refute runner.actionable?("issues")
  end

  def test_extract_sha_from_push
    runner = LocalCI::ActRunner.new(repo_full_name: "test/repo", workflows_dir: @workflows_dir)
    payload = { "after" => "abc123456789" }
    assert_equal "abc123456789", runner.extract_sha("push", payload)
  end

  def test_extract_sha_from_pr
    runner = LocalCI::ActRunner.new(repo_full_name: "test/repo", workflows_dir: @workflows_dir)
    payload = { "pull_request" => { "head" => { "sha" => "def987654321" } } }
    assert_equal "def987654321", runner.extract_sha("pull_request", payload)
  end

  def test_skips_when_no_workflow_files_exist
    runner = LocalCI::ActRunner.new(repo_full_name: "test/repo", workflows_dir: @workflows_dir)
    refute runner.workflows_exist?
  end

  def test_detects_when_workflow_files_exist
    File.write(File.join(@workflows_dir, "test.yml"), "name: Test")
    runner = LocalCI::ActRunner.new(repo_full_name: "test/repo", workflows_dir: @workflows_dir)
    assert runner.workflows_exist?
  end
end
