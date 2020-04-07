require 'thor'
require 'gem_tracker/data'
require 'gem_tracker/gem'

module GemTracker
  class CLI < Thor
    desc "statuses", "Gets the statuses of all gems"
    option :parallel, :type => :boolean
    def statuses()
      say "STATUSES"
      print_statuses_of_gems(GemTracker::GEMS.values)
    end

    desc "status NAME", "Gets the status of a gem"
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
      map(gems, parallel) { |gem|
        [gem, gem.latest_ci_statuses]
      }.each do |gem, statuses|
        print_statuses(gem, statuses, longest_name_size)
      end
    end

    LONGEST_JOB_NAME = 40

    def print_statuses(gem, statuses, first_column_size)
      statuses.each do |status|
        say gem.repo_name.ljust(first_column_size + 1), nil, false
        if status[:success] == true
          say "✓ ", :green, false
        elsif status[:success].nil?
          say "? ", nil, false
        else
          say "✗ ", :red, false
        end

        if status[:version]
          say "#{status[:version].ljust(LONGEST_JOB_NAME)} ", nil, false
        end
        if status[:message]
          say status[:message], nil, false
        end
        if status[:url]
          say status[:url], nil, false
        end
        say "\n"
      end
    end

    def map(enum, parallel, &block)
      if parallel
        parallel_map(enum, &block)
      else
        enum.lazy.map(&block)
      end
    end

    def parallel_map(enum)
      enum.map { |e|
        Thread.new { yield(e) }
      }.map(&:value)
    end
  end
end
