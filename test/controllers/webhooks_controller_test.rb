# frozen_string_literal: true

require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "ping event returns pong" do
    post webhooks_url,
         params: { "zen" => "Practicality beats purity." }.to_json,
         headers: { "Content-Type" => "application/json", "X-GitHub-Event" => "ping" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "pong", json["status"]
  end

  test "push event with matching workflow creates run and enqueues job" do
    payload = {
      "ref" => "refs/heads/main",
      "after" => "32042eb2ea08f0a03f2f7c832e944a3779c5e5fd",
      "repository" => { "full_name" => "user/my-repo" },
      "head_commit" => { "message" => "Feature commit" },
      "pusher" => { "name" => "developer" }
    }

    SolidRun::StatusReporter.stub(:update, true) do
      assert_difference("WorkflowRun.count", 1) do
        assert_enqueued_with(job: ExecuteWorkflowJob) do
          post webhooks_url,
               params: payload.to_json,
               headers: { "Content-Type" => "application/json", "X-GitHub-Event" => "push" }
        end
      end
    end

    assert_response :success
    run = WorkflowRun.last
    assert_equal "user/my-repo", run.repo
    assert_equal "main", run.branch
    assert_equal "queued", run.status
  end
end
