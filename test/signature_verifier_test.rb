# frozen_string_literal: true

require_relative "test_helper"

class SignatureVerifierTest < Minitest::Test
  def setup
    @secret = "my-super-secret-key-123"
    @verifier = LocalCI::SignatureVerifier.new(@secret)
    @payload = '{"action":"opened","number":1}'
  end

  def test_valid_signature_succeeds
    valid_sig = LocalCI::SignatureVerifier.compute_signature(@secret, @payload)
    assert @verifier.valid?(valid_sig, @payload)
  end

  def test_tampered_payload_fails
    valid_sig = LocalCI::SignatureVerifier.compute_signature(@secret, @payload)
    tampered_payload = '{"action":"opened","number":2}'
    refute @verifier.valid?(valid_sig, tampered_payload)
  end

  def test_wrong_secret_fails
    wrong_sig = LocalCI::SignatureVerifier.compute_signature("wrong-secret", @payload)
    refute @verifier.valid?(wrong_sig, @payload)
  end

  def test_missing_signature_header_fails
    refute @verifier.valid?(nil, @payload)
  end

  def test_malformed_signature_prefix_fails
    raw_hash = OpenSSL::HMAC.hexdigest("SHA256", @secret, @payload)
    refute @verifier.valid?(raw_hash, @payload) # Missing "sha256=" prefix
    refute @verifier.valid?("sha1=#{raw_hash}", @payload)
  end

  def test_nil_secret_allows_all_requests
    insecure_verifier = LocalCI::SignatureVerifier.new(nil)
    assert insecure_verifier.valid?(nil, @payload)
    assert insecure_verifier.valid?("invalid", @payload)
  end
end
