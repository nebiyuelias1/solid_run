# frozen_string_literal: true

require "pty"
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

    workspace = ENV["SOLID_RUN_WORKSPACE"] || Rails.root.to_s
    all_succeeded = true
    accumulated_logs = +""

    Tempfile.create(["github_event_", ".json"]) do |file|
      file.write(payload_json || "{}")
      file.flush

      workflow_files.each do |workflow_file|
        header = "\n🚀 [Solid Run] Starting workflow: #{File.basename(workflow_file)}\n" + ("-" * 60) + "\n"
        accumulated_logs << header
        run.append_log(header)

        cmd = ["act", "-W", workflow_file, run.event_type || "push", "-e", file.path]

        begin
          Dir.chdir(workspace) do
            PTY.spawn(*cmd) do |stdout, _stdin, pid|
              stdout.each_line do |line|
                clean_line = line.gsub("\r\n", "\n").gsub("\r", "\n")
                accumulated_logs << clean_line
                run.append_log(clean_line)
              end
            rescue Errno::EIO
              # Reached EOF on Linux PTY
            ensure
              _, status = Process.wait2(pid) if pid rescue nil
              all_succeeded = false unless status&.success?
            end
          end
        rescue StandardError => e
          error_msg = "\n❌ [Solid Run Error] Failed to execute act: #{e.message}\n"
          accumulated_logs << error_msg
          run.append_log(error_msg)
          all_succeeded = false
        end

        footer = ("-" * 60) + "\n"
        accumulated_logs << footer
        run.append_log(footer)
      end
    end

    duration = (Time.current - run.started_at).round(1)
    final_status = all_succeeded ? "success" : "failure"

    run.update!(
      status: final_status,
      completed_at: Time.current,
      duration_seconds: duration,
      logs: accumulated_logs
    )

    finish_msg = "\n🏁 [Solid Run] Run finished with status: #{final_status.upcase} in #{duration}s\n"
    run.append_log(finish_msg)

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
