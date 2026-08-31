# frozen_string_literal: true

require_relative "test_helper"

class EventPrinterTest < Minitest::Test
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def test_print_ping_event
    payload = {
      "zen" => "Approachable is better than simple.",
      "hook" => { "id" => 12345 },
      "repository" => { "full_name" => "user/test-repo" }
    }

    output = capture_stdout do
      LocalCI::EventPrinter.print("ping", payload, delivery_id: "deliv-123")
    end

    assert_includes output, "PING"
    assert_includes output, "Approachable is better than simple."
    assert_includes output, "user/test-repo"
    assert_includes output, "12345"
  end

  def test_print_push_event
    payload = {
      "ref" => "refs/heads/main",
      "pusher" => { "name" => "alice" },
      "repository" => { "full_name" => "alice/app" },
      "commits" => [
        {
          "id" => "1a2b3c4d5e6f",
          "message" => "Fix authentication bug\n\nDetailed notes...",
          "author" => { "name" => "Alice Developer" }
        }
      ]
    }

    output = capture_stdout do
      LocalCI::EventPrinter.print("push", payload)
    end

    assert_includes output, "PUSH"
    assert_includes output, "main"
    assert_includes output, "alice"
    assert_includes output, "1a2b3c4"
    assert_includes output, "Fix authentication bug"
  end

  def test_print_pull_request_event
    payload = {
      "action" => "opened",
      "pull_request" => {
        "number" => 42,
        "title" => "Add awesome CI feature",
        "head" => { "ref" => "feature-branch" },
        "base" => { "ref" => "main" },
        "html_url" => "https://github.com/org/repo/pull/42"
      },
      "sender" => { "login" => "bob" }
    }

    output = capture_stdout do
      LocalCI::EventPrinter.print("pull_request", payload)
    end

    assert_includes output, "PULL_REQUEST"
    assert_includes output, "#42"
    assert_includes output, "Add awesome CI feature"
    assert_includes output, "feature-branch"
    assert_includes output, "bob"
  end

  def test_print_workflow_run_event
    payload = {
      "action" => "completed",
      "workflow_run" => {
        "name" => "Build & Test",
        "head_branch" => "main",
        "conclusion" => "success",
        "actor" => { "login" => "charlie" }
      }
    }

    output = capture_stdout do
      LocalCI::EventPrinter.print("workflow_run", payload)
    end

    assert_includes output, "WORKFLOW_RUN"
    assert_includes output, "Build & Test"
    assert_includes output, "main"
    assert_includes output, "success"
    assert_includes output, "charlie"
  end

  def test_print_workflow_job_event
    payload = {
      "action" => "completed",
      "workflow_job" => {
        "name" => "unit-tests",
        "conclusion" => "success",
        "runner_name" => "github-runner-1"
      }
    }

    output = capture_stdout do
      LocalCI::EventPrinter.print("workflow_job", payload)
    end

    assert_includes output, "WORKFLOW_JOB"
    assert_includes output, "unit-tests"
    assert_includes output, "success"
    assert_includes output, "github-runner-1"
  end
end
