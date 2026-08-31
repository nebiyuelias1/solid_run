# frozen_string_literal: true

class WorkflowRun < ApplicationRecord
  STATUSES = %w[queued in_progress success failure].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  after_create_commit do
    broadcast_prepend_to "workflow_runs",
                         target: "workflow_runs_list",
                         partial: "runs/run_row",
                         locals: { run: self }
  end

  after_update_commit do
    broadcast_replace_to "workflow_runs",
                         target: "run_row_#{id}",
                         partial: "runs/run_row",
                         locals: { run: self }
    broadcast_replace_to "run_#{id}",
                         target: "run_header_#{id}",
                         partial: "runs/run_header",
                         locals: { run: self }
  end

  def queued?
    status == "queued"
  end

  def in_progress?
    status == "in_progress"
  end

  def success?
    status == "success"
  end

  def failed?
    status == "failure"
  end

  def short_sha
    commit_sha.present? ? commit_sha[0..6] : "unknown"
  end

  def duration_display
    return "-" unless duration_seconds
    "#{duration_seconds.round(1)}s"
  end

  def append_log(chunk)
    self.logs = "#{logs}#{chunk}"
    save!
    broadcast_append_to "run_#{id}",
                        target: "run_logs_#{id}",
                        partial: "runs/log_chunk",
                        locals: { chunk: chunk }
  end
end
