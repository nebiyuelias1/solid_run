# frozen_string_literal: true

module LocalCI
  class Git
    attr_reader :owner, :repo, :remote_url

    GITHUB_REMOTE_REGEX = %r{
      \A
      (?:https?://github\.com/|git@github\.com:|ssh://git@github\.com/)
      (?<owner>[^/]+)
      /
      (?<repo>[^/]+?)
      (?:\.git)?
      \z
    }x

    def initialize(remote_name: "origin")
      @remote_name = remote_name
      detect_repository!
    end

    def full_name
      "#{owner}/#{repo}"
    end

    private

    def detect_repository!
      ensure_git_installed!
      ensure_inside_git_repo!

      @remote_url = fetch_remote_url(@remote_name)
      parse_remote_url!(@remote_url)
    end

    def ensure_git_installed!
      stdout, status = Open3.capture2("git", "--version")
      raise Error, "git command not found in PATH" unless status.success?
    end

    def ensure_inside_git_repo!
      _stdout, status = Open3.capture2("git", "rev-parse", "--is-inside-work-tree")
      raise Error, "Current directory is not a Git repository" unless status.success?
    end

    def fetch_remote_url(remote)
      stdout, status = Open3.capture2("git", "remote", "get-url", remote)
      raise Error, "No git remote '#{remote}' found. Please add a GitHub remote origin." unless status.success?

      stdout.strip
    end

    def parse_remote_url!(url)
      match = GITHUB_REMOTE_REGEX.match(url)
      unless match
        raise Error, "Remote '#{@remote_name}' (#{url}) is not a recognizable GitHub repository URL."
      end

      @owner = match[:owner]
      @repo = match[:repo]
    end
  end
end
