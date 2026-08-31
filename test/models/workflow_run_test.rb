# frozen_string_literal: true

require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  test "creates valid workflow run" do
    run = WorkflowRun.create!(
      repo: "user/repo",
      event_type: "push",
      branch: "main",
      commit_sha: "1234567890abcdef",
      status: "queued"
    )

    assert run.persisted?
    assert run.queued?
    assert_equal "1234567", run.short_sha
  end

  test "append_log accumulates logs" do
    run = WorkflowRun.create!(repo: "user/repo", event_type: "push", status: "in_progress", logs: "hello")
    run.append_log(" world\n")

    assert_equal "hello world\n", run.reload.logs
  end
end
