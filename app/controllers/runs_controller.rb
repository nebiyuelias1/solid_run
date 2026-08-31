# frozen_string_literal: true

class RunsController < ApplicationController
  def index
    @runs = WorkflowRun.recent.limit(50)
  end

  def show
    @run = WorkflowRun.find(params[:id])
  end

  def rerun
    @run = WorkflowRun.find(params[:id])
    @run.update!(status: "queued", logs: "", started_at: nil, completed_at: nil, duration_seconds: nil)
    ExecuteWorkflowJob.perform_later(@run.id)

    redirect_to run_path(@run), notice: "Workflow re-queued successfully!"
  end
end
