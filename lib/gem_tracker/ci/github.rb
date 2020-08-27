require 'net/http'
require 'net/https'
require 'json'

class GemTracker::GitHubActions < GemTracker::CI
  def initialize(gem)
    super(gem)
    raise "no workflows configured for #{gem.name}" unless gem.workflows
  end

  def latest_ci_statuses
    statuses = []
    begin
      gem.workflows.each do |w|
        runs = get_workflow_runs(w)
        runs = runs.select { |r| r["head_branch"] == gem.branch }
        runs.each do |r|
          jobs = get_run_jobs(r["jobs_url"])
          jobs.each do |j|
            if j["name"].include?(gem.pattern) and j["conclusion"] != "cancelled"
              url = j["html_url"]
              status = if j["status"] == "in_progress"
                         :in_progress
                       elsif j["status"] == "completed"
                         j["conclusion"] == "success"
                       else
                         nil
                       end
              statuses << {name: gem.name, status: status, version: j["name"], url: url, time: Time.iso8601(j["started_at"])}
            end
          end
          break unless statuses.empty?
        end
      end
      if statuses.empty?
        statuses << {name: gem.name, status: nil, message: "no github run jobs found, workflows: #{gem.workflows.inspect}"}
      end
    rescue => e
      statuses << {status: nil, message: "Statuses Error: #{e.message}"}
      return statuses
    end
    statuses
  end

  def get_run_jobs(jobs_url)
    uri = URI(jobs_url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
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
    url = "https://api.github.com/repos/#{gem.name}/actions/workflows/#{workflow}/runs"
    # puts "workflow runs url: #{url}"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|

      request = Net::HTTP::Get.new uri.request_uri

      user, token = get_github_auth("github get_run_jobs")
      request.basic_auth user, token

      response = http.request request # Net::HTTPResponse object

      json = JSON.parse(response.body)
      json.fetch("workflow_runs") { pp json; raise "Couldn't find workflow runs jobs" }
    end
  end

  def latest_ci_log
    statuses = []
    gem.workflows.each do |w|
      runs = get_workflow_runs(w)
      runs.each do |r|
        if r["head_branch"] == gem.branch
          jobs = get_run_jobs(r["jobs_url"])
          jobs.each do |j|
            if j["name"].include?(gem.pattern)
              url = j["html_url"]
              status = j["conclusion"] == "success"
              statuses << {name: gem.name, status: status, version: j["name"], url: url, job_url: j["url"] }
            end
          end
          break
        end
      end
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
    log_download_url = get_github_log_location(log_url)
    uri = URI(log_download_url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri.request_uri

      user, token = get_github_auth("github logs")
      request.basic_auth(user, token)

      response = http.request(request) # Net::HTTPResponse object

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
    # https://docs.github.com/en/rest/reference/actions#download-job-logs-for-a-workflow-run
    uri = URI(log_url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri.request_uri

      user, token = get_github_auth("github logs")
      request.basic_auth(user, token)

      response = http.request(request) # Net::HTTPResponse object

      if response.code != "302"
        raise "Error getting log location: #{response.body}"
      else
        response['Location']
      end
    end
  end

  register 'github'
end
