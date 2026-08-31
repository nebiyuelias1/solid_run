# frozen_string_literal: true

require "yaml"

module SolidRun
  class WorkflowMatcher
    attr_reader :workflows_dir

    def initialize(workflows_dir: ".github/workflows")
      @workflows_dir = workflows_dir
    end

    # Scans workflow files in @workflows_dir and returns only those matching the event
    def match(event_type, payload)
      return [] unless Dir.exist?(@workflows_dir)

      context = extract_event_context(event_type, payload)

      workflow_files.select do |file|
        workflow_matches?(file, event_type, context)
      end
    end

    def workflow_files
      Dir.glob(File.join(@workflows_dir, "*.{yml,yaml}")).sort
    end

    private

    def workflow_matches?(file, event_type, context)
      content = YAML.safe_load(File.read(file), aliases: true, permitted_classes: [Symbol, Date, Time])
      return false unless content.is_a?(Hash)

      on_config = content["on"] || content[true] || content[:on]
      return false unless on_config

      case on_config
      when String, Symbol
        on_config.to_s == event_type
      when Array
        on_config.map(&:to_s).include?(event_type)
      when Hash
        return false unless on_config.key?(event_type) || on_config.key?(event_type.to_sym)
        trigger_config = on_config[event_type] || on_config[event_type.to_sym]
        matches_hash_trigger?(trigger_config, event_type, context)
      else
        false
      end
    rescue StandardError => e
      warn "⚠️  Failed to parse workflow #{file}: #{e.message}"
      false
    end

    def matches_hash_trigger?(config, event_type, context)
      return false if config.nil?
      return true if config == {} || config == true # e.g. push: {} or push: true

      config = {} unless config.is_a?(Hash)

      # 1. Pull Request Action Types filter
      if event_type == "pull_request"
        allowed_types = Array(config["types"] || %w[opened synchronize reopened]).map(&:to_s)
        return false unless allowed_types.include?(context[:action])
      end

      # 2. Branch filters
      if config.key?("branches")
        branches = Array(config["branches"])
        return false unless context[:branch] && match_any_glob?(branches, context[:branch])
      end

      if config.key?("branches-ignore")
        branches_ignore = Array(config["branches-ignore"])
        return false if context[:branch] && match_any_glob?(branches_ignore, context[:branch])
      end

      # 3. Tag filters
      if config.key?("tags")
        tags = Array(config["tags"])
        return false unless context[:tag] && match_any_glob?(tags, context[:tag])
      end

      if config.key?("tags-ignore")
        tags_ignore = Array(config["tags-ignore"])
        return false if context[:tag] && match_any_glob?(tags_ignore, context[:tag])
      end

      # 4. Path filters
      if context[:changed_files] && !context[:changed_files].empty?
        if config.key?("paths")
          paths = Array(config["paths"])
          matched_any_path = context[:changed_files].any? { |file| match_any_glob?(paths, file) }
          return false unless matched_any_path
        end

        if config.key?("paths-ignore")
          paths_ignore = Array(config["paths-ignore"])
          all_ignored = context[:changed_files].all? { |file| match_any_glob?(paths_ignore, file) }
          return false if all_ignored
        end
      end

      true
    end

    def extract_event_context(event_type, payload)
      context = {
        branch: nil,
        tag: nil,
        action: payload["action"],
        changed_files: []
      }

      case event_type
      when "push"
        ref = payload["ref"].to_s
        if ref.start_with?("refs/heads/")
          context[:branch] = ref.delete_prefix("refs/heads/")
        elsif ref.start_with?("refs/tags/")
          context[:tag] = ref.delete_prefix("refs/tags/")
        end

        commits = payload["commits"] || []
        context[:changed_files] = commits.flat_map do |commit|
          Array(commit["added"]) + Array(commit["modified"]) + Array(commit["removed"])
        end.uniq
      when "pull_request"
        pr = payload["pull_request"] || {}
        context[:branch] = pr.dig("base", "ref")
        # PR payloads don't always contain the list of modified files,
        # so changed_files will be empty unless provided
      end

      context
    end

    def match_any_glob?(patterns, target)
      patterns.any? { |pattern| glob_match?(pattern.to_s, target) }
    end

    def glob_match?(pattern, target)
      regex = glob_to_regex(pattern)
      regex.match?(target)
    end

    def glob_to_regex(pattern)
      p = pattern.dup
      p = p.gsub("/**/", "___ANY_DIR___")
      p = p.gsub("**", "___ANY_PATH___")
      p = p.gsub("*", "___ANY_FILE___")
      p = p.gsub("?", "___ANY_CHAR___")

      escaped = Regexp.escape(p)
      escaped = escaped.gsub("___ANY_DIR___", "(?:/.+)?/")
      escaped = escaped.gsub("___ANY_PATH___", ".*")
      escaped = escaped.gsub("___ANY_FILE___", "[^/]*")
      escaped = escaped.gsub("___ANY_CHAR___", "[^/]")

      Regexp.new("\\A#{escaped}\\z")
    end
  end
end
