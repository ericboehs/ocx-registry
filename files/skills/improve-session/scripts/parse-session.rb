#!/usr/bin/env ruby
# frozen_string_literal: true

# Parse a Claude Code session JSONL file and output a structured JSON summary
# for the session-improver skill to analyze.
#
# Usage:
#   parse-session.rb <session-id>           # Find and parse a specific session
#   parse-session.rb --current              # Parse the current session
#   parse-session.rb <path-to-file.jsonl>   # Parse a specific JSONL file directly

require "json"
require "time"

class SessionParser
  # Patterns that indicate the linter itself produced output (not just a mention in CI summary).
  # We require actual linter output markers, not just the tool name appearing in text.
  LINTER_PATTERNS = {
    "reek" => /(?:warning|smell|--\s+\d+\s+warning)/i,
    "rubocop" => /(?:offenses? detected|C:|W:|E:|no offenses)/i,
    "eslint" => /(?:\d+ problems?|\d+ errors?.*\d+ warnings?)/i,
    "prettier" => /(?:Code style issues found|Forgot to run Prettier)/i,
    "ruff" => /(?:Found \d+ errors?|ruff check)/i,
    "standardrb" => /(?:standard.*offenses?)/i
  }.freeze

  # Match reek output lines: [file_path:line]: SmellType: description
  REEK_SMELL_PATTERN = /\[([^\]]*?):(\d+)\]:\s+(\w+):\s+(.+)/
  RUBOCOP_OFFENSE_PATTERN = /([A-Z]\w+\/\w+):\s+(.+)/

  def initialize(jsonl_path)
    @jsonl_path = jsonl_path
    @entries = []
    @summary = {
      session_id: nil,
      project: nil,
      duration_minutes: 0,
      total_turns: 0,
      total_assistant_turns: 0,
      token_usage: { input: 0, output: 0, cache_read: 0, cache_creation: 0 },
      linter_loops: [],
      tool_failures: [],
      repeated_sequences: [],
      large_reads: [],
      permission_events: [],
      hook_failures: [],
      edit_count: 0,
      tool_call_count: 0,
      agent_spawn_count: 0,
      file_read_tracker: Hash.new(0)
    }
  end

  def parse
    parse_entries
    analyze_entries
    clean_summary
    @summary
  end

  private

  def parse_entries
    File.foreach(@jsonl_path) do |line|
      entry = JSON.parse(line.strip)
      @entries << entry
    rescue JSON::ParserError
      next
    end
  end

  def analyze_entries
    extract_metadata
    extract_token_usage
    detect_linter_loops
    detect_tool_failures
    detect_repeated_sequences
    detect_large_reads
    detect_permission_events
    detect_hook_failures
    count_operations
  end

  def extract_metadata
    first_user = @entries.find { |e| e["type"] == "user" && e["message"].is_a?(Hash) && e.dig("message", "role") == "user" }
    last_entry = @entries.last

    @summary[:session_id] = first_user&.dig("sessionId")
    @summary[:project] = first_user&.dig("cwd")

    if first_user && last_entry
      start_ts = first_user["timestamp"].is_a?(String) ? Time.parse(first_user["timestamp"]) : Time.at(first_user["timestamp"] / 1000.0)
      end_ts = last_entry["timestamp"].is_a?(String) ? Time.parse(last_entry["timestamp"]) : Time.at(last_entry["timestamp"] / 1000.0)
      @summary[:duration_minutes] = ((end_ts - start_ts) / 60).round(1)
    end

    @summary[:total_turns] = @entries.count { |e| e["type"] == "user" && e.dig("message", "role") == "user" && e.dig("message", "content").is_a?(String) }
    @summary[:total_assistant_turns] = @entries.count { |e| e["type"] == "assistant" }
  end

  def extract_token_usage
    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      usage = entry.dig("message", "usage")
      next unless usage

      @summary[:token_usage][:input] += usage["input_tokens"].to_i
      @summary[:token_usage][:output] += usage["output_tokens"].to_i
      @summary[:token_usage][:cache_read] += usage["cache_read_input_tokens"].to_i
      @summary[:token_usage][:cache_creation] += usage["cache_creation_input_tokens"].to_i
    end
  end

  def detect_linter_loops
    # Track sequences of: Edit file → hook failure (linter) → Edit same file
    # A "loop" is when the same file gets edited multiple times due to linter failures
    edit_events = []
    hook_fail_events = []

    @entries.each do |entry|
      # Track edits
      if entry["type"] == "assistant"
        content = entry.dig("message", "content")
        next unless content.is_a?(Array)

        content.each do |block|
          next unless block["type"] == "tool_use" && block["name"] == "Edit"

          file_path = block.dig("input", "file_path")
          edit_events << { file: file_path, timestamp: entry["timestamp"], uuid: entry["uuid"] }
        end
      end

      # Track hook failures from tool results
      if entry["type"] == "user"
        msg_content = entry.dig("message", "content")
        next unless msg_content.is_a?(Array)

        msg_content.each do |block|
          next unless block["type"] == "tool_result" && block["is_error"]

          text = block["content"].to_s
          LINTER_PATTERNS.each do |linter_name, pattern|
            next unless text.match?(pattern)

            # Extract specific smells/offenses
            smells = extract_linter_issues(linter_name, text)
            hook_fail_events << {
              linter: linter_name,
              error_text: text[0..500],
              smells: smells,
              timestamp: entry["timestamp"],
              uuid: entry["uuid"]
            }
          end
        end
      end

      # Also check hook_progress entries for failures
      if entry["type"] == "progress" && entry.dig("data", "type") == "hook_progress"
        # Hook failures show up in subsequent tool_result entries
      end
    end

    # Now correlate: find edit→fail→edit sequences on the same file
    linter_loop_map = Hash.new { |h, k| h[k] = { iterations: 0, smells: Hash.new(0), files: Set.new, error_samples: [] } }

    hook_fail_events.each do |fail_event|
      fail_event[:smells].each do |smell|
        key = "#{fail_event[:linter]}:#{smell[:type]}"
        linter_loop_map[key][:iterations] += 1
        linter_loop_map[key][:smells][smell[:type]] += 1
        linter_loop_map[key][:files].add(smell[:file]) if smell[:file]
        if linter_loop_map[key][:error_samples].size < 2
          linter_loop_map[key][:error_samples] << smell[:message][0..200]
        end
      end
    end

    linter_loop_map.each do |key, data|
      linter, smell = key.split(":", 2)
      next if data[:iterations] < 2 # Only report if it happened more than once

      @summary[:linter_loops] << {
        linter: linter,
        smell: smell,
        iterations: data[:iterations],
        files: data[:files].to_a,
        error_samples: data[:error_samples]
      }
    end

    # Sort by iterations descending
    @summary[:linter_loops].sort_by! { |l| -l[:iterations] }
  end

  def extract_linter_issues(linter, text)
    issues = []
    case linter
    when "reek"
      # Match: [file_path:line]: SmellType: description
      text.scan(REEK_SMELL_PATTERN).each do |file_path, line, smell_type, message|
        issues << { type: smell_type, message: message.strip, file: file_path, line: line.to_i }
      end
      # Fallback: match smell names in summary text (e.g., "FeatureEnvy")
      if issues.empty?
        known_smells = %w[FeatureEnvy TooManyStatements DuplicateMethodCall ControlParameter
                          DataClump UncommunicativeVariableName UncommunicativeMethodName
                          UncommunicativeModuleName UtilityFunction TooManyMethods
                          LongParameterList BooleanParameter NilCheck InstanceVariableAssumption
                          ManualDispatch NestedIterators RepeatedConditional TooManyInstanceVariables]
        known_smells.each do |smell|
          if text.include?(smell)
            issues << { type: smell, message: smell, file: nil }
          end
        end
      end
    when "rubocop"
      text.scan(RUBOCOP_OFFENSE_PATTERN).each do |cop, message|
        issues << { type: cop, message: message.strip, file: nil }
      end
    end
    issues
  end

  def detect_tool_failures
    # Find tool calls that failed and were retried with similar input
    tool_attempts = Hash.new { |h, k| h[k] = [] }

    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      content = entry.dig("message", "content")
      next unless content.is_a?(Array)

      content.each do |block|
        next unless block["type"] == "tool_use"

        tool_name = block["name"]
        tool_id = block["id"]
        input_summary = summarize_tool_input(block["input"])

        tool_attempts["#{tool_name}:#{input_summary}"] << {
          tool: tool_name,
          tool_id: tool_id,
          input_summary: input_summary,
          timestamp: entry["timestamp"]
        }
      end
    end

    # Find the error results
    error_results = {}
    @entries.each do |entry|
      next unless entry["type"] == "user"

      msg_content = entry.dig("message", "content")
      next unless msg_content.is_a?(Array)

      msg_content.each do |block|
        next unless block["type"] == "tool_result" && block["is_error"]

        error_results[block["tool_use_id"]] = block["content"].to_s[0..300]
      end
    end

    # Report tools that were called 3+ times with similar input
    tool_attempts.each do |key, attempts|
      next if attempts.size < 3

      tool_name = attempts.first[:tool]
      failed_count = attempts.count { |a| error_results[a[:tool_id]] }
      next if failed_count < 2

      @summary[:tool_failures] << {
        tool: tool_name,
        input_summary: attempts.first[:input_summary],
        retry_count: attempts.size,
        error_count: failed_count,
        error_sample: error_results.values_at(*attempts.map { |a| a[:tool_id] }).compact.first
      }
    end
  end

  def summarize_tool_input(input)
    return "" unless input.is_a?(Hash)

    # Create a fuzzy key for grouping similar calls
    case
    when input["command"]
      # Bash: normalize whitespace and extract command name
      cmd = input["command"].to_s.strip.split(/\s+/).first(3).join(" ")
      "cmd:#{cmd}"
    when input["file_path"]
      "file:#{input["file_path"]}"
    when input["pattern"]
      "pattern:#{input["pattern"]}"
    when input["query"]
      "query:#{input["query"][0..50]}"
    else
      input.keys.sort.join(",")
    end
  end

  def detect_repeated_sequences
    # Track tool calls with simplified input context for meaningful pattern detection.
    # We want to find workflows like "Read file → Edit file → Bash(rubocop)" repeating.
    tool_sequence = []

    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      content = entry.dig("message", "content")
      next unless content.is_a?(Array)

      content.each do |block|
        next unless block["type"] == "tool_use"

        # Use tool name + simplified category for better pattern matching
        tool_label = case block["name"]
                     when "Bash"
                       cmd = block.dig("input", "command").to_s.split(/\s+/).first(2).join(" ")
                       "Bash(#{cmd})"
                     when "Edit", "Write", "Read"
                       ext = File.extname(block.dig("input", "file_path").to_s)
                       "#{block["name"]}(#{ext})"
                     else
                       block["name"]
                     end
        tool_sequence << tool_label
      end
    end

    # Look for repeating subsequences of length 3-5, requiring diversity (not all same tool)
    found = {}
    (3..5).each do |window_size|
      next if tool_sequence.size < window_size * 2

      subsequence_count = Hash.new(0)
      (0..tool_sequence.size - window_size).each do |i|
        subseq = tool_sequence[i, window_size]
        # Skip if all entries are the same tool (not a meaningful workflow)
        next if subseq.map { |s| s.split("(").first }.uniq.size < 2

        subsequence_count[subseq] += 1
      end

      subsequence_count.each do |subseq, count|
        next if count < 3

        key = subseq.join(" → ")
        # Keep the highest count for overlapping subsequences
        if !found[key] || found[key][:count] < count
          found[key] = { sequence: subseq, count: count, length: window_size }
        end
      end
    end

    @summary[:repeated_sequences] = found.values
      .sort_by { |s| [-s[:count], -s[:length]] }
      .first(5)
  end

  def detect_large_reads
    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      content = entry.dig("message", "content")
      next unless content.is_a?(Array)

      content.each do |block|
        next unless block["type"] == "tool_use" && block["name"] == "Read"

        file_path = block.dig("input", "file_path")
        next unless file_path

        @summary[:file_read_tracker][file_path] += 1
      end
    end

    # Report files read 3+ times
    @summary[:large_reads] = @summary[:file_read_tracker]
      .select { |_, count| count >= 3 }
      .map { |file, count| { file: file, times_read: count } }
      .sort_by { |r| -r[:times_read] }
  end

  def detect_permission_events
    permission_counts = Hash.new(0)

    @entries.each do |entry|
      # Permission prompts show up as specific message patterns
      next unless entry["type"] == "user" && entry["permissionMode"]

      msg_content = entry.dig("message", "content")
      next unless msg_content.is_a?(Array)

      msg_content.each do |block|
        next unless block["type"] == "tool_result"

        # The tool_use_id links back to the tool that needed permission
        permission_counts[block["tool_use_id"]] += 1
      end
    end

    # Cross-reference with the tool calls to get tool names
    tool_names = {}
    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      content = entry.dig("message", "content")
      next unless content.is_a?(Array)

      content.each do |block|
        next unless block["type"] == "tool_use"

        tool_names[block["id"]] = { tool: block["name"], input: summarize_tool_input(block["input"]) }
      end
    end

    # Aggregate by tool+input pattern
    pattern_counts = Hash.new(0)
    permission_counts.each_key do |tool_id|
      info = tool_names[tool_id]
      next unless info

      pattern_counts["#{info[:tool]}|#{info[:input]}"] += 1
    end

    pattern_counts.each do |pattern, count|
      tool, input = pattern.split("|", 2)
      @summary[:permission_events] << { tool: tool, input_pattern: input, count: count }
    end
  end

  def detect_hook_failures
    hook_fail_counts = Hash.new { |h, k| h[k] = { count: 0, errors: [] } }

    @entries.each do |entry|
      next unless entry["type"] == "user"

      msg_content = entry.dig("message", "content")
      next unless msg_content.is_a?(Array)

      msg_content.each do |block|
        next unless block["type"] == "tool_result" && block["is_error"]

        text = block["content"].to_s

        # Check if this came from a hook (look at surrounding progress entries)
        @entries.each do |progress|
          next unless progress["type"] == "progress"
          next unless progress.dig("data", "type") == "hook_progress"
          next unless progress["toolUseID"] == block["tool_use_id"]

          hook_name = progress.dig("data", "hookName") || "unknown"
          hook_fail_counts[hook_name][:count] += 1
          hook_fail_counts[hook_name][:errors] << text[0..200] if hook_fail_counts[hook_name][:errors].size < 2
          break
        end
      end
    end

    hook_fail_counts.each do |hook, data|
      next if data[:count] < 2

      @summary[:hook_failures] << {
        hook_name: hook,
        count: data[:count],
        error_samples: data[:errors]
      }
    end
  end

  def count_operations
    @entries.each do |entry|
      next unless entry["type"] == "assistant"

      content = entry.dig("message", "content")
      next unless content.is_a?(Array)

      content.each do |block|
        next unless block["type"] == "tool_use"

        @summary[:tool_call_count] += 1
        @summary[:edit_count] += 1 if block["name"] == "Edit" || block["name"] == "Write"
        @summary[:agent_spawn_count] += 1 if block["name"] == "Agent"
      end
    end
  end

  def clean_summary
    # Remove internal tracking fields
    @summary.delete(:file_read_tracker)

    # Remove empty arrays
    @summary.each do |key, value|
      @summary[key] = [] if value.is_a?(Array) && value.all?(&:nil?)
    end
  end
end

class SessionFinder
  HISTORY_FILE = File.expand_path("~/.claude/history.jsonl")
  PROJECTS_DIR = File.expand_path("~/.claude/projects")

  def self.find(identifier)
    if identifier == "--current"
      find_current_session
    elsif File.exist?(identifier)
      identifier
    else
      find_by_session_id(identifier)
    end
  end

  def self.find_current_session
    # Get the most recent session ID from history.jsonl
    last_line = nil
    File.foreach(HISTORY_FILE) { |line| last_line = line }
    return nil unless last_line

    entry = JSON.parse(last_line.strip)
    session_id = entry["sessionId"]
    find_by_session_id(session_id)
  end

  def self.find_by_session_id(session_id)
    # Search through projects directory for the JSONL file
    Dir.glob(File.join(PROJECTS_DIR, "**", "#{session_id}.jsonl")).first ||
      Dir.glob(File.join(PROJECTS_DIR, "**", "#{session_id}", "**", "*.jsonl")).first
  end
end

# Main
identifier = ARGV[0] || "--current"
jsonl_path = SessionFinder.find(identifier)

unless jsonl_path && File.exist?(jsonl_path)
  warn "Could not find session file for: #{identifier}"
  warn "Usage: parse-session.rb <session-id | --current | path/to/file.jsonl>"
  exit 1
end

parser = SessionParser.new(jsonl_path)
summary = parser.parse

puts JSON.pretty_generate(summary)
