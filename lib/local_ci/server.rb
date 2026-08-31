# frozen_string_literal: true

require "webrick"
require "json"

module LocalCI
  class Server
    attr_reader :port, :host, :webrick_server, :server_thread

    def initialize(port: 4567, host: "127.0.0.1", on_event: nil)
      @port = port
      @host = host
      @on_event = on_event || method(:default_event_handler)
      @webrick_server = nil
      @server_thread = nil
    end

    def start
      # Mute WEBrick's internal noisy logs to keep the console clean for events
      null_logger = WEBrick::Log.new(File::NULL, WEBrick::Log::FATAL)
      null_access_log = [[File::NULL, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]

      @webrick_server = WEBrick::HTTPServer.new(
        Port: @port,
        BindAddress: @host,
        Logger: null_logger,
        AccessLog: null_access_log
      )

      mount_routes

      @server_thread = Thread.new { @webrick_server.start }
      puts "🚀 Local HTTP server listening on http://#{@host}:#{@port}"
      self
    end

    def stop
      return unless @webrick_server

      puts "🛑 Stopping HTTP server..."
      @webrick_server.shutdown
      @server_thread&.join(2)
      @webrick_server = nil
    end

    private

    def mount_routes
      handler = @on_event

      # Health check endpoint
      @webrick_server.mount_proc "/health" do |_req, res|
        res.status = 200
        res["Content-Type"] = "application/json"
        res.body = JSON.generate({ status: "running", service: "local-ci" })
      end

      # Webhook endpoint
      webhook_proc = proc do |req, res|
        if req.request_method == "POST"
          event_type = req["x-github-event"] || "unknown"
          delivery_id = req["x-github-delivery"]

          begin
            payload = req.body ? JSON.parse(req.body) : {}
            handler.call(event_type, payload, delivery_id)

            res.status = 200
            res["Content-Type"] = "application/json"
            res.body = JSON.generate({ status: "ok", event: event_type })
          rescue JSON::ParserError => e
            res.status = 400
            res["Content-Type"] = "application/json"
            res.body = JSON.generate({ error: "Invalid JSON payload: #{e.message}" })
          rescue StandardError => e
            res.status = 500
            res["Content-Type"] = "application/json"
            res.body = JSON.generate({ error: e.message })
          end
        else
          res.status = 200
          res["Content-Type"] = "application/json"
          res.body = JSON.generate({ status: "running", service: "local-ci" })
        end
      end

      @webrick_server.mount_proc "/webhook", &webhook_proc
      @webrick_server.mount_proc "/", &webhook_proc
    end

    def default_event_handler(event_type, payload, delivery_id)
      EventPrinter.print(event_type, payload, delivery_id: delivery_id)
    end
  end
end
