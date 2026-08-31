# frozen_string_literal: true

module SolidRun
  class LogParser
    Step = Struct.new(:job, :name, :status, :lines, :duration, keyword_init: true)

    def self.parse(raw_logs)
      return [] if raw_logs.blank?

      steps = []
      current_step = nil
      job_steps = {} # Map of "job_name" => active Step

      raw_logs.each_line do |line|
        clean_line = line.strip

        # Match Step Start: e.g. "[CI/test] ⭐ Run Run Tests" or "⭐ Run Run Tests"
        if (match = clean_line.match(/(?:\[(.*?)\]\s*)?⭐\s*Run\s+(.*)/))
          job_name = match[1] || "default"
          step_name = match[2].strip

          # Complete previous step if any for this job
          if (prev = job_steps[job_name])
            prev.status = "success" if prev.status == "in_progress"
          end

          step = Step.new(
            job: job_name,
            name: step_name,
            status: "in_progress",
            lines: [],
            duration: nil
          )
          steps << step
          job_steps[job_name] = step
          next
        end

        # Match Step Success: e.g. "[CI/test]   ✅  Success - Run Tests"
        if (match = clean_line.match(/(?:\[(.*?)\]\s*)?✅\s*Success\s*-\s*(.*)/))
          job_name = match[1] || "default"
          step_name = match[2]&.strip
          if (active = job_steps[job_name])
            active.status = "success"
          end
          next
        end

        # Match Step Failure: e.g. "[CI/test]   ❌  Failure - Run Tests"
        if (match = clean_line.match(/(?:\[(.*?)\]\s*)?❌\s*Failure\s*-\s*(.*)/))
          job_name = match[1] || "default"
          step_name = match[2]&.strip
          if (active = job_steps[job_name])
            active.status = "failure"
          end
          next
        end

        # Match Job Completion: e.g. "[CI/test] 🏁  Job succeeded" / "Job failed"
        if (match = clean_line.match(/(?:\[(.*?)\]\s*)?🏁\s*Job\s+(succeeded|failed)/))
          job_name = match[1] || "default"
          status = match[2] == "succeeded" ? "success" : "failure"
          if (active = job_steps[job_name])
            active.status = status if active.status == "in_progress"
          end
          job_steps.delete(job_name)
          next
        end

        # Extract Job Name from normal log lines: e.g. "[CI/test] | line content"
        if (match = clean_line.match(/^\[(.*?)\]\s*(.*)/))
          job_name = match[1]
          content = match[2]
          active = job_steps[job_name]

          # If no step exists yet, create an initial "Setup" step
          unless active
            active = Step.new(job: job_name, name: "Job Initialization", status: "in_progress", lines: [])
            steps << active
            job_steps[job_name] = active
          end

          active.lines << content.delete_prefix("| ")
        else
          # Global line (e.g. starting workflow header or docker daemon log)
          if steps.empty?
            steps << Step.new(job: "Workflow", name: "Workflow Initialization", status: "success", lines: [])
          end
          steps.last.lines << clean_line.delete_prefix("| ")
        end
      end

      # Mark any remaining in_progress steps as success if run completed
      steps
    end
  end
end
