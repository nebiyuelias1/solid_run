# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_signature!

  def create
    event_type = request.headers["X-GitHub-Event"] || "push"
    raw_body = request.raw_post
    payload = raw_body.present? ? JSON.parse(raw_body) : {}

    if event_type == "ping"
      render json: { status: "pong", zen: payload["zen"] }, status: :ok
      return
    end

    matcher = SolidRun::WorkflowMatcher.new
    matched_files = matcher.match(event_type, payload)

    if matched_files.empty?
      render json: { status: "skipped", message: "No workflows matched event filters" }, status: :ok
      return
    end

    repo_full_name = payload.dig("repository", "full_name") || "unknown/repo"
    branch = extract_branch(event_type, payload)
    commit_sha = extract_sha(event_type, payload)
    commit_msg = extract_commit_message(event_type, payload)
    author = extract_author(event_type, payload)

    run = WorkflowRun.create!(
      repo: repo_full_name,
      event_type: event_type,
      branch: branch,
      commit_sha: commit_sha,
      commit_message: commit_msg,
      author: author,
      status: "queued",
      workflow_files: matched_files.join(", ")
    )

    # Compute target_url pointing to the live run dashboard
    tunnel_url = ENV["SOLID_RUN_TUNNEL_URL"] || request.base_url
    target_url = "#{tunnel_url.chomp('/')}/runs/#{run.id}"
    run.update!(target_url: target_url)

    # Report queued status to GitHub
    if commit_sha.present?
      SolidRun::StatusReporter.update(
        repo_full_name: repo_full_name,
        sha: commit_sha,
        state: "pending",
        description: "Queued in Local CI...",
        target_url: target_url
      )
    end

    # Enqueue in Solid Queue
    ExecuteWorkflowJob.perform_later(run.id, raw_body)

    render json: { status: "queued", run_id: run.id, target_url: target_url }, status: :ok
  rescue JSON::ParserError => e
    render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
  end

  private

  def verify_signature!
    secret = ENV["SOLID_RUN_SECRET"]
    return if secret.blank?

    signature = request.headers["X-Hub-Signature-256"]
    verifier = SolidRun::SignatureVerifier.new(secret)

    unless verifier.valid?(signature, request.raw_post)
      render json: { error: "Unauthorized: Invalid or missing X-Hub-Signature-256" }, status: :unauthorized
    end
  end

  def extract_branch(event_type, payload)
    case event_type
    when "push"
      ref = payload["ref"].to_s
      ref.delete_prefix("refs/heads/").delete_prefix("refs/tags/")
    when "pull_request"
      payload.dig("pull_request", "head", "ref") || payload.dig("pull_request", "base", "ref")
    end
  end

  def extract_sha(event_type, payload)
    case event_type
    when "push"
      sha = payload["after"] || payload.dig("head_commit", "id")
      sha unless sha == "0000000000000000000000000000000000000000"
    when "pull_request"
      payload.dig("pull_request", "head", "sha")
    end
  end

  def extract_commit_message(event_type, payload)
    case event_type
    when "push"
      payload.dig("head_commit", "message")&.lines&.first&.strip
    when "pull_request"
      payload.dig("pull_request", "title")
    end
  end

  def extract_author(event_type, payload)
    case event_type
    when "push"
      payload.dig("pusher", "name") || payload.dig("sender", "login")
    when "pull_request"
      payload.dig("sender", "login")
    end
  end
end
