# frozen_string_literal: true

require "tempfile"
require "json"
require "open3"
require "time"

module LocalCI
  class ActRunner
    ACTIONABLE_EVENTS = %w[push pull_request workflow_dispatch].freeze

    attr_reader :repo_full_name, :workflows_dir, :extra_args, :report_status

    def initialize(repo_full_name:, workflows_dir: ".github/workflows", extra_args: [], report_status: true)
      @repo_full_name = repo_full_name
      @workflows_dir = workflows_dir
      @extra_args = extra_args || []
      @report_status = report_status
    end

    def execute(event_type, payload)
      return unless actionable?(event_type)

      matcher = WorkflowMatcher.new(workflows_dir: @workflows_dir)
      matched_files = matcher.match(event_type, payload)

      if matched_files.empty?
        puts "\n💡 No workflows in #{@workflows_dir}/ matched trigger filters for '#{event_type}'. Skipping act run."
        return true
      end

      sha = extract_sha(event_type, payload)
      start_time = Time.now

      matched_names = matched_files.map { |f| File.basename(f) }.join(", ")
      puts "\n#{EventPrinter::BOLD}🚀 Triggering Local CI Runner (act)...#{EventPrinter::RESET}"
      puts "   Event     : #{EventPrinter::CYAN}#{event_type}#{EventPrinter::RESET}"
      puts "   Workflows : #{EventPrinter::GREEN}#{matched_names}#{EventPrinter::RESET}"
      puts "   Commit    : #{EventPrinter::YELLOW}#{sha || 'unknown'}#{EventPrinter::RESET}"

      if @report_status && sha
        StatusReporter.update(
          repo_full_name: @repo_full_name,
          sha: sha,
          state: "pending",
          description: "Running #{matched_names} locally..."
        )
      end

      all_succeeded = matched_files.all? do |workflow_file|
        puts "\n#{EventPrinter::BOLD}▶️ Running workflow: #{File.basename(workflow_file)}#{EventPrinter::RESET}"
        run_act_for_workflow(workflow_file, event_type, payload)
      end

      elapsed = (Time.now - start_time).round(1)

      if all_succeeded
        puts "\n#{EventPrinter::GREEN}🎉 All matched workflows SUCCEEDED in #{elapsed}s!#{EventPrinter::RESET}\n"
        if @report_status && sha
          StatusReporter.update(
            repo_full_name: @repo_full_name,
            sha: sha,
            state: "success",
            description: "Local CI passed in #{elapsed}s"
          )
        end
      else
        puts "\n#{EventPrinter::RED}❌ One or more workflows FAILED in #{elapsed}s.#{EventPrinter::RESET}\n"
        if @report_status && sha
          StatusReporter.update(
            repo_full_name: @repo_full_name,
            sha: sha,
            state: "failure",
            description: "Local CI failed in #{elapsed}s"
          )
        end
      end

      all_succeeded
    end

    def actionable?(event_type)
      ACTIONABLE_EVENTS.include?(event_type)
    end

    def workflows_exist?
      Dir.exist?(@workflows_dir) && !Dir.glob(File.join(@workflows_dir, "*.{yml,yaml}")).empty?
    end

    def extract_sha(event_type, payload)
      case event_type
      when "push"
        sha = payload["after"] || payload.dig("head_commit", "id")
        sha unless sha == "0000000000000000000000000000000000000000"
      when "pull_request"
        payload.dig("pull_request", "head", "sha")
      when "workflow_dispatch"
        payload.dig("workflow_run", "head_sha") || payload["ref"]
      end
    end

    private

    def run_act_for_workflow(workflow_file, event_type, payload)
      Tempfile.create(["github_event_", ".json"]) do |file|
        file.write(JSON.generate(payload))
        file.flush

        cmd = ["act", "-W", workflow_file, event_type, "-e", file.path] + @extra_args
        puts "🐳 Running: #{cmd.join(' ')}\n\n"

        system(*cmd)
      end
    end
  end
end
