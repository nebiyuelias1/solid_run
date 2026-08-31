# frozen_string_literal: true

require "openssl"

module SolidRun
  class SignatureVerifier
    SIGNATURE_PREFIX = "sha256="

    attr_reader :secret

    def initialize(secret)
      @secret = secret
    end

    # Validates GitHub's X-Hub-Signature-256 header against the raw payload body
    def valid?(signature_header, payload_body)
      return true if @secret.nil? || @secret.to_s.empty?
      return false if signature_header.nil? || payload_body.nil?
      return false unless signature_header.start_with?(SIGNATURE_PREFIX)

      given_signature = signature_header.delete_prefix(SIGNATURE_PREFIX)
      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", @secret, payload_body)

      secure_compare(given_signature, expected_signature)
    end

    # Helper method to compute a valid signature for testing
    def self.compute_signature(secret, payload_body)
      "#{SIGNATURE_PREFIX}#{OpenSSL::HMAC.hexdigest('SHA256', secret, payload_body)}"
    end

    private

    def secure_compare(a, b)
      return false unless a.is_a?(String) && b.is_a?(String)

      if OpenSSL.respond_to?(:secure_compare)
        OpenSSL.secure_compare(a, b)
      else
        return false unless a.bytesize == b.bytesize

        l = a.unpack("C*")
        r = b.unpack("C*")
        res = 0
        l.each_with_index { |byte, i| res |= byte ^ r[i] }
        res.zero?
      end
    end
  end
end
