require 'concurrent'
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
    option :ruby, :type => :string, :default => nil
    option :days, :type => :numeric, :default => -1
    def statuses()
      say "STATUSES"
      print_statuses_of_gems(GemTracker::GEMS.values)
    end

    desc "status NAME", "Gets the status of a gem"
    option :aggregate, :type => :boolean, :default => true
    option :ruby, :type => :string, :default => nil
    option :days, :type => :numeric, :default => -1
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
        begin
          latest_ci_statuses = gem.latest_ci_statuses
        rescue => e
          latest_ci_statuses = [
            GemTracker::Status.new(gem: gem, job_name: "", result: e, url: nil, time: nil, job_url: nil)
          ]
        end

        [gem, latest_ci_statuses]
      }.each do |gem, statuses|
        success = print_statuses(gem, statuses, longest_name_size)
        failing << gem.name unless success
      end

      abort "Failing CIs: #{failing.join(', ')}" unless failing.empty?
    end

    LONGEST_JOB_NAME = 40

    def print_statuses(gem, statuses, first_column_size)
      statuses = statuses.select do |status|
        if options[:ruby]
          release, head = status.job_name.match?(/truffleruby(?!-head)/), status.job_name.include?('truffleruby-head')
          if options[:ruby] == 'head'
            !release || head
          elsif options[:ruby] == 'release'
            !head || release
          else
            raise "Invalid ruby option: #{options[:ruby].inspect}"
          end
        else
          true
        end
      end

      if options[:aggregate] and statuses.size > 1 and statuses.map(&:result).uniq.size == 1
        versions = statuses.map(&:job_name)
        first = versions.first
        prefix = first.size.downto(0).find { |i| versions.all? { |v| v.start_with?(first[0...i]) } }
        suffix = first.size.downto(1).find { |i| versions.all? { |v| v.end_with?(first[-i..-1]) } }
        summary = "#{first[0...prefix]}...#{first[-suffix..-1] if suffix and suffix != first.size}"
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
          if gem.expect == :fail
            say "✗ ", :blue, false
          elsif options[:days] > 0 and status.time and ((Time.now - status.time) / 86400) > options[:days]
            say "o ", :blue, false
          else
            ok = false
            say "✗ ", :red, false
          end
        else
          ok = false
          say "? #{status.result.inspect}", nil, false
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
      semaphore = Concurrent::Semaphore.new(5)
      queue = Queue.new
      threads = enum.map { |e|
        Thread.new {
          semaphore.acquire
          begin
            sleep rand(0.0..1.0)
            queue << [Thread.current, yield(e)]
          ensure
            semaphore.release
          end
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
