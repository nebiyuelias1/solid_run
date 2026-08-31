# frozen_string_literal: true

require "open3"

module LocalCI
  class StatusReporter
    CONTEXT = "Local CI (act)"

    def self.update(repo_full_name:, sha:, state:, description:, target_url: nil)
      return unless sha && !sha.empty? && sha != "0000000000000000000000000000000000000000"

      args = [
        { "MISE_QUIET" => "1" },
        "gh", "api", "repos/#{repo_full_name}/statuses/#{sha}",
        "-f", "state=#{state}",
        "-f", "context=#{CONTEXT}",
        "-f", "description=#{description}"
      ]
      args += ["-f", "target_url=#{target_url}"] if target_url

      _stdout, stderr, status = Open3.capture3(*args)
      unless status.success?
        warn "⚠️  Could not update GitHub commit status: #{stderr.strip}"
      end
    rescue StandardError => e
      warn "⚠️  Failed to report status to GitHub: #{e.message}"
    end
  end
end
