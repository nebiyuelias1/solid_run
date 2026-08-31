# frozen_string_literal: true

require "open3"
require "tempfile"

class ExecuteWorkflowJob < ApplicationJob
  queue_as :default

  # Ensure only one workflow runs at a time per repository, or allow concurrency
  limits_concurrency to: 1, key: ->(run_id, *) { WorkflowRun.find_by(id: run_id)&.repo || "global" }

  def perform(run_id, payload_json = nil)
    run = WorkflowRun.find_by(id: run_id)
    return unless run

    run.update!(status: "in_progress", started_at: Time.current, logs: "")

    # Notify GitHub that job is in progress with link to dashboard
    if run.commit_sha.present?
      SolidRun::StatusReporter.update(
        repo_full_name: run.repo,
        sha: run.commit_sha,
        state: "pending",
        description: "Building in Local CI...",
        target_url: run.target_url
      )
    end

    workflow_files = (run.workflow_files || "").split(",").map(&:strip).reject(&:empty?)
    workflow_files = [".github/workflows/ci.yml"] if workflow_files.empty?

    all_succeeded = true

    Tempfile.create(["github_event_", ".json"]) do |file|
      file.write(payload_json || "{}")
      file.flush

      workflow_files.each do |workflow_file|
        run.append_log("\n🚀 [Solid Run] Starting workflow: #{File.basename(workflow_file)}\n")
        run.append_log("-" * 60 + "\n")

        cmd = ["act", "-W", workflow_file, run.event_type || "push", "-e", file.path]

        workspace = ENV["SOLID_RUN_WORKSPACE"] || Rails.root.to_s
        Open3.popen2e(*cmd, chdir: workspace) do |_stdin, stdout_and_err, wait_thr|
          stdout_and_err.each_line do |line|
            run.append_log(line)
          end
          all_succeeded = false unless wait_thr.value.success?
        end

        run.append_log("-" * 60 + "\n")
      end
    end

    duration = (Time.current - run.started_at).round(1)
    final_status = all_succeeded ? "success" : "failure"

    run.update!(
      status: final_status,
      completed_at: Time.current,
      duration_seconds: duration
    )

    run.append_log("\n🏁 [Solid Run] Run finished with status: #{final_status.upcase} in #{duration}s\n")

    # Notify GitHub of final status with target_url
    if run.commit_sha.present?
      SolidRun::StatusReporter.update(
        repo_full_name: run.repo,
        sha: run.commit_sha,
        state: final_status,
        description: "Local CI #{final_status == 'success' ? 'passed' : 'failed'} in #{duration}s",
        target_url: run.target_url
      )
    end
  end
end
