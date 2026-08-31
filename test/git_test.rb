# frozen_string_literal: true

require_relative "test_helper"

class GitTest < Minitest::Test
  def test_regex_matching_ssh_url
    url = "git@github.com:nebiyuelias1/local-ci.git"
    match = LocalCI::Git::GITHUB_REMOTE_REGEX.match(url)
    assert match
    assert_equal "nebiyuelias1", match[:owner]
    assert_equal "local-ci", match[:repo]
  end

  def test_regex_matching_ssh_url_without_dot_git
    url = "git@github.com:octocat/Hello-World"
    match = LocalCI::Git::GITHUB_REMOTE_REGEX.match(url)
    assert match
    assert_equal "octocat", match[:owner]
    assert_equal "Hello-World", match[:repo]
  end

  def test_regex_matching_https_url
    url = "https://github.com/my-org/my-project.git"
    match = LocalCI::Git::GITHUB_REMOTE_REGEX.match(url)
    assert match
    assert_equal "my-org", match[:owner]
    assert_equal "my-project", match[:repo]
  end

  def test_regex_matching_ssh_protocol_url
    url = "ssh://git@github.com/developer/repo.git"
    match = LocalCI::Git::GITHUB_REMOTE_REGEX.match(url)
    assert match
    assert_equal "developer", match[:owner]
    assert_equal "repo", match[:repo]
  end

  def test_regex_rejects_non_github_urls
    url = "https://gitlab.com/owner/repo.git"
    match = LocalCI::Git::GITHUB_REMOTE_REGEX.match(url)
    assert_nil match
  end
end
