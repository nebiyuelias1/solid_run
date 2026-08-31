# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class WorkflowMatcherTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir("matcher_test_")
    @workflows_dir = File.join(@tmp_dir, ".github", "workflows")
    FileUtils.mkdir_p(@workflows_dir)
    @matcher = LocalCI::WorkflowMatcher.new(workflows_dir: @workflows_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def write_workflow(filename, content)
    path = File.join(@workflows_dir, filename)
    File.write(path, content)
    path
  end

  def test_matches_simple_string_trigger
    wf = write_workflow("push.yml", <<~YAML)
      name: Push CI
      on: push
    YAML

    payload = { "ref" => "refs/heads/main" }
    assert_equal [wf], @matcher.match("push", payload)
    assert_empty @matcher.match("pull_request", payload)
  end

  def test_matches_array_triggers
    wf = write_workflow("multi.yml", <<~YAML)
      name: Multi
      on: [push, pull_request]
    YAML

    assert_equal [wf], @matcher.match("push", { "ref" => "refs/heads/main" })
    assert_equal [wf], @matcher.match("pull_request", { "action" => "opened", "pull_request" => { "base" => { "ref" => "main" } } })
    assert_empty @matcher.match("workflow_dispatch", {})
  end

  def test_branch_filtering
    wf = write_workflow("branches.yml", <<~YAML)
      name: Branches
      on:
        push:
          branches:
            - main
            - 'release/**'
    YAML

    assert_equal [wf], @matcher.match("push", { "ref" => "refs/heads/main" })
    assert_equal [wf], @matcher.match("push", { "ref" => "refs/heads/release/1.0" })
    assert_empty @matcher.match("push", { "ref" => "refs/heads/feature-abc" })
  end

  def test_branches_ignore_filtering
    wf = write_workflow("ignore.yml", <<~YAML)
      name: Ignore
      on:
        push:
          branches-ignore:
            - 'feat/**'
    YAML

    assert_equal [wf], @matcher.match("push", { "ref" => "refs/heads/main" })
    assert_empty @matcher.match("push", { "ref" => "refs/heads/feat/new-ui" })
  end

  def test_paths_filtering
    wf = write_workflow("paths.yml", <<~YAML)
      name: Paths
      on:
        push:
          paths:
            - 'lib/**'
            - 'Gemfile*'
    YAML

    matching_payload = {
      "ref" => "refs/heads/main",
      "commits" => [{ "modified" => ["lib/local_ci/git.rb"] }]
    }
    non_matching_payload = {
      "ref" => "refs/heads/main",
      "commits" => [{ "modified" => ["docs/README.md"] }]
    }

    assert_equal [wf], @matcher.match("push", matching_payload)
    assert_empty @matcher.match("push", non_matching_payload)
  end

  def test_paths_ignore_filtering
    wf = write_workflow("paths_ignore.yml", <<~YAML)
      name: Paths Ignore
      on:
        push:
          paths-ignore:
            - 'docs/**'
            - '*.md'
    YAML

    doc_only_payload = {
      "ref" => "refs/heads/main",
      "commits" => [{ "modified" => ["docs/setup.md", "README.md"] }]
    }
    code_payload = {
      "ref" => "refs/heads/main",
      "commits" => [{ "modified" => ["lib/app.rb", "README.md"] }]
    }

    assert_empty @matcher.match("push", doc_only_payload)
    assert_equal [wf], @matcher.match("push", code_payload)
  end

  def test_pull_request_action_types
    wf = write_workflow("pr_types.yml", <<~YAML)
      name: PR Types
      on:
        pull_request:
          types: [opened, synchronize]
    YAML

    opened_payload = { "action" => "opened", "pull_request" => { "base" => { "ref" => "main" } } }
    closed_payload = { "action" => "closed", "pull_request" => { "base" => { "ref" => "main" } } }

    assert_equal [wf], @matcher.match("pull_request", opened_payload)
    assert_empty @matcher.match("pull_request", closed_payload)
  end

  def test_multiple_workflows_selective_matching
    wf_ci = write_workflow("ci.yml", <<~YAML)
      name: CI
      on:
        push:
          branches: [main]
    YAML

    wf_deploy = write_workflow("deploy.yml", <<~YAML)
      name: Deploy
      on:
        push:
          branches: [production]
    YAML

    main_push = { "ref" => "refs/heads/main" }
    prod_push = { "ref" => "refs/heads/production" }

    assert_equal [wf_ci], @matcher.match("push", main_push)
    assert_equal [wf_deploy], @matcher.match("push", prod_push)
  end
end
