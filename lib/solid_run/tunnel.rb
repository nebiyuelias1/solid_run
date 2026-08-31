# frozen_string_literal: true

require "open3"
require "timeout"

module SolidRun
  class Tunnel
    attr_reader :url, :port, :pid

    TUNNEL_URL_REGEX = %r{https://[a-zA-Z0-9-]+\.trycloudflare\.com}

    def initialize(port:)
      @port = port
      @url = nil
      @stdin = nil
      @stdout_and_err = nil
      @wait_thr = nil
      @thread = nil
    end

    def start(timeout: 15)
      ensure_cloudflared_installed!

      puts "🌐 Starting Cloudflare Quick Tunnel on port #{port}..."
      
      @stdin, @stdout_and_err, @wait_thr = Open3.popen2e(
        "cloudflared", "tunnel",
        "--url", "http://127.0.0.1:#{port}",
        "--no-autoupdate"
      )
      @pid = @wait_thr.pid

      url_queue = Queue.new

      @thread = Thread.new do
        found = false
        @stdout_and_err.each_line do |line|
          if !found && (match = line.match(TUNNEL_URL_REGEX))
            found = true
            url_queue << match[0]
          end
        end
      rescue IOError
        # Stream closed on stop
      end

      begin
        Timeout.timeout(timeout) do
          @url = url_queue.pop
        end
      rescue Timeout::Error
        stop
        raise Error, "Timed out waiting for Cloudflare tunnel URL. Ensure cloudflared can reach the internet."
      end

      puts "✨ Tunnel ready: #{@url}"
      @url
    end

    def stop
      return unless @wait_thr&.alive?

      puts "🛑 Closing Cloudflare tunnel (PID: #{@pid})..."
      begin
        Process.kill("TERM", @pid) if @pid
        @stdin&.close unless @stdin&.closed?
        @stdout_and_err&.close unless @stdout_and_err&.closed?
        @wait_thr.join(3)
        Process.kill("KILL", @pid) if @wait_thr.alive?
      rescue StandardError => e
        # Ignore errors during process shutdown
      end
    end

    private

    def ensure_cloudflared_installed!
      stdout, status = Open3.capture2("cloudflared", "--version")
      unless status.success?
        raise Error, "cloudflared is not installed or not in PATH.\n" \
                     "Please install cloudflared:\n" \
                     "  - Ubuntu/Debian: sudo apt install cloudflared\n" \
                     "  - macOS: brew install cloudflared\n" \
                     "  - Or download binary from: https://github.com/cloudflare/cloudflared/releases"
      end
    rescue Errno::ENOENT
      raise Error, "cloudflared executable not found in PATH."
    end
  end
end
