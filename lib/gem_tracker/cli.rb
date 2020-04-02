require 'thor'
require 'gem_tracker/data'
require 'gem_tracker/gem'

module GemTracker
  class CLI < Thor
    desc "statuses", "Gets the statuses of all gems"

    def statuses()
      say "STATUSES"
      GemTracker::GEMS.each_value do |gem|
        print_statuses(gem)
      end
    end

    desc "status NAME", "Gets the status of a gem"

    def status(name)
      gem = GemTracker::GEMS[name]
      raise "unkown name `#{name}`" unless gem
      print_statuses(gem)
    end

    desc "log NAME", "Prints the log for the latest build"

    def log(name)
      gem = GemTracker::GEMS[name]
      raise "unkown name `#{name}`" unless gem
      gem.latest_ci_log
    end

    private

    def print_statuses(gem)
      statuses = gem.latest_ci_statuses
      statuses.each do |status|
        say "#{gem.name} ", nil, false
        if status[:version]
          say "#{status[:version]} ", nil, false
        end
        if status[:success] == true
          say "\u2713 ".encode('utf-8'), :green, false
        elsif status[:success].nil?
          say "? ", nil, false
        else
          say "\u2717 ".encode('utf-8'), :red, false
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
  end
end