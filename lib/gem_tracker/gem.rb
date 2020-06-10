require 'dotenv/load'
require 'travis/client'
require 'net/http'
require 'net/https'
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
      File.basename(name)
    end

    def latest_ci_log
      case ci
      when "travis"
        travis_ci_log
      when "github"
        github_ci_log
      else
        [{name: name, status: nil, message: "unsupported log ci: #{ci}"}]
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
        [{name: name, status: nil, message: "unknown ci: #{ci}"}]
      end
    end

    def github_ci_log
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
                  status = j["conclusion"] == "success"
                  statuses << {name: name, status: status, version: j["name"], url: url, job_url: j["url"] }
                end
              end
              break
            end
          end
        end
      else
        puts "no workflows configured for #{name}"
      end
      if statuses.empty?
        puts "no github run jobs logs found, workflows: #{workflows.inspect}"
      end
      statuses.each do |s|
        puts "LOG: version: #{s[:version]}, status: #{s[:status]}, url: #{s[:url]}"
        print_github_log(s[:job_url])
        puts "LOG: version: #{s[:version]}, status: #{s[:status]}, url: #{s[:url]}"
      end
    end

    def print_github_log(job_url)
      log_url = "#{job_url}/logs"
      #puts "log_url: #{log_url.inspect}"
      log_download_url = get_github_log_location(log_url)
      #puts "log_download_url: #{log_download_url.inspect}"
      uri = URI(log_download_url)
      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      ) do |http|

        request = Net::HTTP::Get.new uri.request_uri

        user, token = get_github_auth("github logs")
        request.basic_auth user, token


        response = http.request request # Net::HTTPResponse object

        puts response.body
      end

    end

    def get_github_auth(feature)
      auth = ENV['GEM_TRACKER_GITHUB_AUTH']
      unless auth
        raise "#{feature} requires GEM_TRACKER_GITHUB_AUTH environment variable set to github_user:token, See documentation to create tokens: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line"
      end
      auth.split(':')
    end

    def get_github_log_location(log_url)
      # https://api.github.com/repos/puma/puma/actions/jobs/550162360/logs
      # https://developer.github.com/v3/actions/workflow_jobs/#list-workflow-job-logs
      # :verify_mode => OpenSSL::SSL::VERIFY_NONE
      uri = URI(log_url)
      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      ) do |http|

        request = Net::HTTP::Get.new uri.request_uri

        user, token = get_github_auth("github logs")
        request.basic_auth user, token


        response = http.request request # Net::HTTPResponse object

        #puts "response code #{response.code}"
        if response.code != "302"
          raise "Error getting log location: #{response.body}"
        else
          response['Location']
        end
      end
    end

    def github_ci_statuses
      statuses = []
      begin
        if workflows
          workflows.each do |w|
            runs = get_workflow_runs(w)
            runs.each do |r|
              if r["head_branch"] == "master"
                jobs = get_run_jobs(r["jobs_url"])
                jobs.each do |j|
                  if j["name"].include?("truffleruby")
                    url = j["html_url"]
                    status = j["conclusion"] == "success"
                    statuses << {name: name, status: status, version: j["name"], url: url}
                  end
                end
                break
              end
            end
          end
        else
          statuses << {name: name, status: nil, message: "no workflows configured for #{name}"}
        end
        if statuses.empty?
          statuses << {name: name, status: nil, message: "no github run jobs found, workflows: #{workflows.inspect}"}
        end
      rescue => e
        statuses << {status: nil, message: "Statuses Error: #{e.message}"}
        return statuses
      end
      statuses
    end

    def get_run_jobs(jobs_url)
      uri = URI(jobs_url)
      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      ) do |http|

        request = Net::HTTP::Get.new uri.request_uri

        user, token = get_github_auth("github get_run_jobs")
        request.basic_auth user, token

        response = http.request request # Net::HTTPResponse object

        json = JSON.parse(response.body)
        json.fetch("jobs") { pp json; raise "Couldn't find runs jobs" }
      end
    end

    def get_workflow_runs(workflow)
      # https://api.github.com/repos/rack/rack/actions/workflows/development.yml/runs
      url = "https://api.github.com/repos/#{name}/actions/workflows/#{workflow}/runs"
      # puts "workflow runs url: #{url}"
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      ) do |http|

        request = Net::HTTP::Get.new uri.request_uri

        user, token = get_github_auth("github get_run_jobs")
        request.basic_auth user, token

        response = http.request request # Net::HTTPResponse object

        json = JSON.parse(response.body)
        json.fetch("workflow_runs") { pp json; raise "Couldn't find workflow runs jobs" }
      end
    end

    def get_travis_com_auth(feature)
      auth = ENV['GEM_TRACKER_TRAVIS_COM_AUTH']
      unless auth
        raise "#{feature} requires GEM_TRACKER_TRAVIS_COM_AUTH environment variable set to token, visit your settings page at travis-ci.com to get your token"
      end
      auth
    end

    def travis_ci_log(org = true)
      puts "LOGS"
      begin
        client = if org
                   Travis::Client.new
                 else
                   Travis::Client.new(:uri => Travis::Client::COM_URI, :access_token => get_travis_com_auth("travis-ci.com logs"))
                 end
        repo = client.find_one(Travis::Client::Repository, name) # E.g. 'rails/rails'
        branch = repo.last_on_branch('master')

        branch.jobs.each do |j|
          if j.config.include?("rvm") && j.config["rvm"].is_a?(String) && j.config["rvm"].include?('truffleruby')
            url = "https://travis-ci.org/#{name}/jobs/#{j.id}"
            puts "LOG: version: #{j.config["rvm"]}, status: #{j.color}, url: #{url}"
            puts j.log.colorized_body
            puts "LOG: version: #{j.config["rvm"]}, status: #{j.color}, url: #{url}"
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
        if org
          client = Travis::Client.new
        else
          begin
            auth = get_travis_com_auth("travis-ci.com statuses")
            client = Travis::Client.new(:uri => Travis::Client::COM_URI, :access_token => auth)
          rescue => e
            statuses << {status: nil, message: "Status Error: #{e.message}"}
            return statuses
          end
        end
        repo = client.find_one(Travis::Client::Repository, name) # E.g. 'rails/rails'
        branch = repo.last_on_branch('master')

        branch.jobs.each do |j|
          if j.config.include?("rvm") && j.config["rvm"].is_a?(String) && j.config["rvm"].include?('truffleruby')
            url = "https://travis-ci.org/#{name}/jobs/#{j.id}"
            statuses << {:status => j.color, :version => j.config["rvm"], :url => url}
          end
        end
      rescue => e
        statuses << {status: nil, message: "Status Error: #{e.message}"}
      end
      if statuses.empty?
        statuses << {name: name, status: nil, message: "no truffleruby travis jobs found"}
      end
      statuses
    end
  end
end