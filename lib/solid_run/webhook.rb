# frozen_string_literal: true

require "json"
require "open3"

module SolidRun
  class Webhook
    attr_reader :repo_full_name, :tunnel_url, :hook_id, :secret

    DEFAULT_EVENTS = %w[push pull_request workflow_run workflow_job].freeze

    def initialize(repo_full_name:, tunnel_url:, secret: nil)
      @repo_full_name = repo_full_name
      @tunnel_url = tunnel_url
      @secret = secret
      @hook_id = nil
    end

    def register(events: DEFAULT_EVENTS)
      ensure_gh_authenticated!

      webhook_url = "#{tunnel_url.chomp('/')}/webhook"
      puts "🔗 Registering GitHub webhook on #{repo_full_name} -> #{webhook_url}..."

      config = {
        url: webhook_url,
        content_type: "json",
        insecure_ssl: "0"
      }
      config[:secret] = @secret if @secret && !@secret.empty?

      payload = {
        name: "web",
        active: true,
        events: events,
        config: config
      }

      stdout, stderr, status = Open3.capture3(
        { "MISE_QUIET" => "1" },
        "gh", "api", "repos/#{repo_full_name}/hooks",
        "--input", "-",
        stdin_data: JSON.generate(payload)
      )

      response = parse_json_response(stdout)

      unless status.success?
        errs = response["errors"]&.map { |e| e["message"] }&.compact&.join("; ")
        error_details = if errs && !errs.empty?
                          "#{response['message']}: #{errs}"
                        elsif response["message"]
                          response["message"]
                        else
                          stderr.strip
                        end
        raise Error, "Failed to register webhook on #{repo_full_name}: #{error_details}"
      end

      @hook_id = response["id"]
      puts "✅ Webhook registered successfully (Hook ID: #{@hook_id})"
      @hook_id
    end

    def delete
      return unless @hook_id

      puts "🗑️  Deleting GitHub webhook (ID: #{@hook_id}) from #{repo_full_name}..."
      _stdout, stderr, status = Open3.capture3(
        { "MISE_QUIET" => "1" },
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

    def parse_json_response(output)
      return {} if output.nil? || output.strip.empty?

      # Find first '{' or '[' to bypass any tool wrapper messages (e.g. mise/asdf shims)
      json_start = output.index(/[\{\[]/)
      return {} unless json_start

      JSON.parse(output[json_start..])
    rescue JSON::ParserError
      {}
    end

    def ensure_gh_authenticated!
      _stdout, stderr, status = Open3.capture3({ "MISE_QUIET" => "1" }, "gh", "auth", "status")
      unless status.success?
        raise Error, "gh CLI is not authenticated.\nPlease run 'gh auth login' first."
      end
    rescue Errno::ENOENT
      raise Error, "gh CLI is not installed or not in PATH.\nPlease install GitHub CLI (gh)."
    end
  end
end
