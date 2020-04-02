require 'travis/client'
require 'net/http'
require 'json'

module GemTracker

  class Gem
    attr_accessor :name, :ci, :workflows

    def self.from_hash(hash)
      g = Gem.new
      g.name = hash["name"]
      g.ci = hash["ci"]
      g.workflows = hash["workflows"]
      g
    end

    def repo_name
      name.split('/').last
    end

    def latest_ci_log
      case ci
      when "travis"
        travis_ci_log
      else
        [{name: name, success: nil, message: "unsupported log ci: #{ci}"}]
      end
    end

    def latest_ci_statuses
      case ci
      when "travis"
        travis_ci_statuses
      when "traviscom"
        travis_ci_statuses(false)
      when "github"
        github_ci_statuses
      else
        [{name: name, success: nil, message: "unknown ci: #{ci}"}]
      end
    end

    def github_ci_statuses
      statuses = []
      if workflows
        workflows.each do |w|
          runs = get_workflow_runs(w)
          runs.each do |r|
            if r["head_branch"] == "master"
              jobs = get_run_jobs(r["jobs_url"])
              jobs.each do |j|
                if j["name"].include?("truffleruby")
                  url = j["html_url"]
                  success = j["conclusion"] == "success"
                  statuses << {name: name, success: success, version: j["name"], url: url}
                end
              end
              break
            end
          end
        end
      else
        statuses << {name: name, success: nil, message: "no workflows configured for #{name}"}
      end
      if statuses.empty?
        statuses << {name: name, success: nil, message: "no github run jobs found, workflows: #{workflows.inspect}"}
      end
      statuses
    end

    def get_run_jobs(jobs_url)
      # https://api.github.com/repos/rack/rack/actions/runs/53810299/jobs
      response = Net::HTTP.get(URI(jobs_url))
      json = JSON.parse(response)
      json["jobs"]
    end

    def get_workflow_runs(workflow)
      # https://api.github.com/repos/rack/rack/actions/workflows/development.yml/runs
      url = "https://api.github.com/repos/#{name}/actions/workflows/#{workflow}/runs"
      # puts "workflow runs url: #{url}"
      response = Net::HTTP.get(URI(url))
      json = JSON.parse(response)
      json["workflow_runs"]
    end

    def travis_ci_log(org = true)
      puts "LOGS"
      begin
        client = if org
                   Travis::Client.new
                 else
                   Travis::Client.new(:uri => Travis::Client::COM_URI)
                 end
        repo = client.find_one(Travis::Client::Repository, name) # E.g. 'rails/rails'
        branch = repo.last_on_branch('master')

        branch.jobs.each do |j|
          if j.config.include?("rvm") && j.config["rvm"].is_a?(String) && j.config["rvm"].include?('truffleruby')
            url = "https://travis-ci.org/#{name}/jobs/#{j.id}"
            puts "LOG: version: #{j.config["rvm"]}, success: #{j.successful?}, url: #{url}"
            puts j.log.colorized_body
            puts "LOG: version: #{j.config["rvm"]}, success: #{j.successful?}, url: #{url}"
          end
        end
      rescue => e
        puts "LOG ERROR:"
        puts e.message
      end
    end

    def travis_ci_statuses(org = true)
      statuses = []
      begin
        client = if org
                   Travis::Client.new
                 else
                   Travis::Client.new(:uri => Travis::Client::COM_URI)
                 end
        repo = client.find_one(Travis::Client::Repository, name) # E.g. 'rails/rails'
        branch = repo.last_on_branch('master')

        branch.jobs.each do |j|
          if j.config.include?("rvm") && j.config["rvm"].is_a?(String) && j.config["rvm"].include?('truffleruby')
            url = "https://travis-ci.org/#{name}/jobs/#{j.id}"
            statuses << {:success => j.successful?, :version => j.config["rvm"], :url => url}
          end
        end
      rescue => e
        statuses << {:success => nil, :message => "Status Error: #{e.message}"}
      end
      statuses
    end
  end
end