# frozen_string_literal: true

require "json"
require "open3"

module LocalCI
  class Webhook
    attr_reader :repo_full_name, :tunnel_url, :hook_id

    DEFAULT_EVENTS = %w[push pull_request workflow_dispatch ping].freeze

    def initialize(repo_full_name:, tunnel_url:)
      @repo_full_name = repo_full_name
      @tunnel_url = tunnel_url
      @hook_id = nil
    end

    def register(events: DEFAULT_EVENTS)
      ensure_gh_authenticated!

      webhook_url = "#{tunnel_url.chomp('/')}/webhook"
      puts "🔗 Registering GitHub webhook on #{repo_full_name} -> #{webhook_url}..."

      payload = {
        name: "web",
        active: true,
        events: events,
        config: {
          url: webhook_url,
          content_type: "json",
          insecure_ssl: "0"
        }
      }

      stdout, stderr, status = Open3.capture3(
        "gh", "api", "repos/#{repo_full_name}/hooks",
        "--input", "-",
        stdin_data: JSON.generate(payload)
      )

      unless status.success?
        raise Error, "Failed to register webhook on #{repo_full_name}: #{stderr.strip}"
      end

      response = JSON.parse(stdout)
      @hook_id = response["id"]
      puts "✅ Webhook registered successfully (Hook ID: #{@hook_id})"
      @hook_id
    end

    def delete
      return unless @hook_id

      puts "🗑️  Deleting GitHub webhook (ID: #{@hook_id}) from #{repo_full_name}..."
      _stdout, stderr, status = Open3.capture3(
        "gh", "api", "-X", "DELETE", "repos/#{repo_full_name}/hooks/#{@hook_id}"
      )

      if status.success?
        puts "✅ Webhook #{@hook_id} deleted."
        @hook_id = nil
      else
        warn "⚠️  Could not delete webhook #{@hook_id}: #{stderr.strip}"
      end
    end

    private

    def ensure_gh_authenticated!
      _stdout, stderr, status = Open3.capture3("gh", "auth", "status")
      unless status.success?
        raise Error, "gh CLI is not authenticated.\nPlease run 'gh auth login' first."
      end
    rescue Errno::ENOENT
      raise Error, "gh CLI is not installed or not in PATH.\nPlease install GitHub CLI (gh)."
    end
  end
end
