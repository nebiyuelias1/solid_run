# frozen_string_literal: true

require "time"

module LocalCI
  class EventPrinter
    # ANSI color helpers
    RESET   = "\e[0m"
    BOLD    = "\e[1m"
    DIM     = "\e[2m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    RED     = "\e[31m"

    def self.print(event_type, payload, delivery_id: nil)
      new(event_type, payload, delivery_id).render
    end

    def initialize(event_type, payload, delivery_id)
      @event_type = event_type
      @payload = payload
      @delivery_id = delivery_id
      @timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    end

    def render
      puts "\n" + ("=" * 60)
      puts "#{BOLD}📦 [GITHUB EVENT]#{RESET} #{CYAN}#{@event_type.upcase}#{RESET} #{DIM}(#{@timestamp})#{RESET}"
      puts "#{DIM}Delivery ID: #{@delivery_id}#{RESET}" if @delivery_id
      puts "-" * 60

      case @event_type
      when "ping"
        render_ping
      when "push"
        render_push
      when "pull_request"
        render_pull_request
      when "workflow_dispatch"
        render_workflow_dispatch
      when "issues"
        render_issues
      else
        render_generic
      end

      puts ("=" * 60) + "\n"
    end

    private

    def render_ping
      zen = @payload["zen"]
      hook_id = @payload.dig("hook", "id")
      repo = @payload.dig("repository", "full_name")

      puts "#{GREEN}⚡ Ping received successfully!#{RESET}"
      puts "Repository : #{BOLD}#{repo}#{RESET}" if repo
      puts "Hook ID    : #{hook_id}" if hook_id
      puts "Zen        : \"#{zen}\"" if zen
    end

    def render_push
      ref = @payload["ref"] || "unknown"
      branch = ref.sub(%r{\Arefs/heads/}, "")
      pusher = @payload.dig("pusher", "name") || @payload.dig("sender", "login") || "unknown"
      commits = @payload["commits"] || []
      repo = @payload.dig("repository", "full_name")

      puts "Repository : #{BOLD}#{repo}#{RESET}" if repo
      puts "Branch     : #{YELLOW}#{branch}#{RESET} #{DIM}(#{ref})#{RESET}"
      puts "Pushed by  : #{MAGENTA}#{pusher}#{RESET}"
      puts "Commits    : #{commits.size}"

      commits.each_with_index do |commit, idx|
        sha = commit["id"] ? commit["id"][0..6] : "unknown"
        msg = (commit["message"] || "").lines.first&.strip
        author = commit.dig("author", "name") || "unknown"
        puts "  #{DIM}[#{idx + 1}]#{RESET} #{CYAN}#{sha}#{RESET} - #{msg} #{DIM}(by #{author})#{RESET}"
      end
    end

    def render_pull_request
      action = @payload["action"]
      pr = @payload["pull_request"] || {}
      number = pr["number"] || @payload["number"]
      title = pr["title"]
      sender = @payload.dig("sender", "login") || "unknown"
      head = pr.dig("head", "ref")
      base = pr.dig("base", "ref")

      puts "Action     : #{BOLD}#{action}#{RESET}"
      puts "PR         : ##{number} - #{title}"
      puts "Branches   : #{YELLOW}#{head}#{RESET} -> #{YELLOW}#{base}#{RESET}"
      puts "Author     : #{MAGENTA}#{sender}#{RESET}"
      puts "URL        : #{pr["html_url"]}" if pr["html_url"]
    end

    def render_workflow_dispatch
      workflow = @payload["workflow"]
      ref = @payload["ref"]
      sender = @payload.dig("sender", "login") || "unknown"
      inputs = @payload["inputs"]

      puts "Workflow   : #{BOLD}#{workflow}#{RESET}"
      puts "Ref        : #{YELLOW}#{ref}#{RESET}"
      puts "Triggered  : #{MAGENTA}#{sender}#{RESET}"
      puts "Inputs     : #{inputs.inspect}" if inputs && !inputs.empty?
    end

    def render_issues
      action = @payload["action"]
      issue = @payload["issue"] || {}
      number = issue["number"]
      title = issue["title"]
      sender = @payload.dig("sender", "login") || "unknown"

      puts "Action     : #{BOLD}#{action}#{RESET}"
      puts "Issue      : ##{number} - #{title}"
      puts "User       : #{MAGENTA}#{sender}#{RESET}"
    end

    def render_generic
      sender = @payload.dig("sender", "login")
      repo = @payload.dig("repository", "full_name")

      puts "Repository : #{repo}" if repo
      puts "Sender     : #{sender}" if sender
      puts "Keys       : #{@payload.keys.join(', ')}"
    end
  end
end
