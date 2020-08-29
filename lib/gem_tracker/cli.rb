require 'thor'
require_relative 'data'

# Always #say in color
class Thor::Shell::Color
  def can_display_colors?
    true
  end
end

module GemTracker
  class CLI < Thor
    desc "statuses", "Gets the statuses of all gems"
    option :parallel, :type => :boolean
    option :aggregate, :type => :boolean, :default => true
    def statuses()
      say "STATUSES"
      print_statuses_of_gems(GemTracker::GEMS.values)
    end

    desc "status NAME", "Gets the status of a gem"
    option :aggregate, :type => :boolean, :default => true
    def status(name)
      gem = find_gem(name)
      print_statuses_of_gems([gem])
    end

    desc "log NAME", "Prints the log for the latest build"
    def log(name)
      gem = find_gem(name)
      gem.latest_ci_log
    end

    private

    def find_gem(name)
      if name.include? '/'
        GemTracker::GEMS.fetch(name) { raise NameError, "unknown gem `#{name}`" }
      else
        gems = GemTracker::GEMS.values.select { |gem| gem.repo_name == name }
        if gems.empty?
          raise NameError, "unknown gem `#{name}`"
        elsif gems.size == 1
          gems.first
        else
          raise "Multiple gems matching #{name}: #{gems}"
        end
      end
    end

    def print_statuses_of_gems(gems)
      parallel = options[:parallel]

      longest_name_size = gems.max_by { |g| g.repo_name.size }.repo_name.size
      failing = []
      map(gems, parallel) { |gem|
        [gem, gem.latest_ci_statuses]
      }.each do |gem, statuses|
        failing << gem.name unless print_statuses(gem, statuses, longest_name_size)
      end

      abort "Failing CIs: #{failing.join(', ')}" unless failing.empty?
    end

    LONGEST_JOB_NAME = 40

    def print_statuses(gem, statuses, first_column_size)
      if options[:aggregate] and statuses.size > 1 and statuses.map(&:result).uniq.size == 1
        versions = statuses.map(&:job_name)
        first = versions.first
        prefix = first.size.downto(0).find { |i| versions.all? { |v| v.start_with?(first[0...i]) } }
        suffix = first.size.downto(1).find { |i| versions.all? { |v| v.end_with?(first[-i..-1]) } }
        summary = "#{first[0...prefix]}...#{first[-suffix..-1] if suffix}"
        statuses = [statuses.first.dup.tap { |s| s.job_name = summary }]
      end

      ok = true
      statuses.each do |status|
        say gem.repo_name.ljust(first_column_size + 1), nil, false
        case status.result
        when :success
          say "✓ ", :green, false
          warn_passing = true if gem.expect == :fail
        when :in_progress
          say "⌛ ", :yellow, false
        when :failure
          color = if gem.expect == :fail
                    :blue
                  else
                    ok = false
                    :red
                  end
          say "✗ ", color, false
        else
          say "? ", nil, false
        end

        if status.time
          say "#{status.time.strftime('%d-%m-%Y')} ", nil, false
        end
        if status.job_name
          say "#{status.job_name.ljust(LONGEST_JOB_NAME)} ", nil, false
        end
        if status.url
          say status.url, nil, false
        end
        say "\n"

        say "WARNING: #{gem.name} was marked as failing but passed!" , [:bold, :magenta] if warn_passing
      end
      ok
    end

    def map(enum, parallel, &block)
      if parallel
        parallel_map(enum, &block)
      else
        enum.lazy.map(&block)
      end
    end

    def parallel_map(enum)
      queue = Queue.new
      threads = enum.map { |e|
        Thread.new {
          queue << [Thread.current, yield(e)]
        }
      }

      Enumerator.new do |y|
        threads.size.times do
          thread, result = queue.pop
          thread.join
          y.yield result
        end
      end
    end
  end
end
