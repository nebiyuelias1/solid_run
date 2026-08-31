# frozen_string_literal: true

require_relative "test_helper"

class ServerTest < Minitest::Test
  def setup
    @secret = "test-secret-key-xyz"
    @received_events = []
    @server = LocalCI::Server.new(
      port: 9876,
      host: "127.0.0.1",
      secret: @secret,
      on_event: ->(event_type, payload, delivery_id) {
        @received_events << { type: event_type, payload: payload, delivery_id: delivery_id }
      }
    )
    @server.start
    sleep 0.2
  end

  def teardown
    @server.stop
  end

  def test_health_endpoint
    uri = URI("http://127.0.0.1:9876/health")
    response = Net::HTTP.get_response(uri)

    assert_equal "200", response.code
    json = JSON.parse(response.body)
    assert_equal "running", json["status"]
  end

  def test_post_webhook_with_valid_signature_succeeds
    uri = URI("http://127.0.0.1:9876/webhook")
    req = Net::HTTP::Post.new(uri)
    body = JSON.generate({ "ref" => "refs/heads/feature", "pusher" => { "name" => "tester" } })
    sig = LocalCI::SignatureVerifier.compute_signature(@secret, body)

    req["Content-Type"] = "application/json"
    req["X-GitHub-Event"] = "push"
    req["X-GitHub-Delivery"] = "test-uuid-456"
    req["X-Hub-Signature-256"] = sig
    req.body = body

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

    assert_equal "200", response.code
    assert_equal 1, @received_events.size
    event = @received_events.first
    assert_equal "push", event[:type]
    assert_equal "test-uuid-456", event[:delivery_id]
    assert_equal "refs/heads/feature", event[:payload]["ref"]
  end

  def test_post_webhook_with_invalid_signature_rejected
    uri = URI("http://127.0.0.1:9876/webhook")
    req = Net::HTTP::Post.new(uri)
    body = JSON.generate({ "ref" => "refs/heads/feature" })

    req["Content-Type"] = "application/json"
    req["X-GitHub-Event"] = "push"
    req["X-Hub-Signature-256"] = "sha256=invalidhexsignature0000000000000000000000000000000000000000000000"
    req.body = body

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

    assert_equal "401", response.code
    json = JSON.parse(response.body)
    assert_includes json["error"], "Unauthorized"
    assert_empty @received_events
  end

  def test_post_webhook_missing_signature_rejected
    uri = URI("http://127.0.0.1:9876/webhook")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["X-GitHub-Event"] = "push"
    req.body = JSON.generate({ "ref" => "refs/heads/feature" })

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

    assert_equal "401", response.code
    assert_empty @received_events
  end
end
