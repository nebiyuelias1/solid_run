# frozen_string_literal: true

require "test_helper"

class RunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @run = WorkflowRun.create!(
      repo: "user/repo",
      event_type: "push",
      branch: "main",
      status: "queued"
    )
  end

  test "should get index" do
    get runs_url
    assert_response :success
    assert_select "h1", "Workflow Runs"
  end

  test "should show run" do
    get run_url(@run)
    assert_response :success
    assert_select "h3", "Execution Steps"
  end

  test "should rerun run" do
    assert_enqueued_with(job: ExecuteWorkflowJob, args: [@run.id]) do
      post rerun_run_url(@run)
    end
    assert_redirected_to run_url(@run)
  end
end
