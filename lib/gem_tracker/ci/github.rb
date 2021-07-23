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
    gem.workflows.each do |w|
      runs = get_workflow_runs(w)
      runs = runs.select { |r| r["head_branch"] == gem.branch }
      runs.each do |r|
        # p r['created_at']
        jobs = get_run_jobs(r["jobs_url"])
        jobs.each do |j|
          # p j["name"]
          if j["name"].downcase.include?(gem.pattern) and j["conclusion"] != "cancelled"
            url = j["html_url"]
            result = if j["status"] == "in_progress"
                       :in_progress
                     elsif j["status"] == "completed"
                       if j["conclusion"] == "success"
                        # need to verify runs since continue-on-error status is success for errors
                        annotations = get_annotations(j["check_run_url"])
                        if annotations.any? { |a| a['annotation_level'] == 'failure' }
                          :failure
                        else
                          :success
                        end
                       else
                        :failure
                       end
                     else
                       :unknown
                     end
            statuses << GemTracker::Status.new(gem: gem, result: result, job_name: j["name"], url: url, time: Time.iso8601(j["started_at"]), job_url: j["url"])
          end
        end
        break unless statuses.empty?
      end
    end

    raise "no github run jobs found, workflows: #{gem.workflows.inspect}" if statuses.empty?
    statuses
  end

  def get_annotations(check_run_url)
    annotations_url = "#{check_run_url}/annotations"
    request(annotations_url) do |response|
      JSON.parse(response.body)
    end  
  end

  # https://docs.github.com/en/rest/reference/actions#list-jobs-for-a-workflow-run
  def get_run_jobs(jobs_url)
    jobs_url = "#{jobs_url}?per_page=100"
    request(jobs_url) do |response|
      json = JSON.parse(response.body)
      jobs = json.fetch("jobs") { pp json; raise "Couldn't find runs jobs" }
      if jobs.size != json['total_count']
        raise "request did not return all jobs: #{jobs.size} of #{json['total_count']}"
      end
      jobs
    end
  end

  def get_workflow_runs(workflow)
    # https://api.github.com/repos/rack/rack/actions/workflows/development.yml/runs
    url = "https://api.github.com/repos/#{gem.name}/actions/workflows/#{workflow}/runs"
    request(url) do |response|
      json = JSON.parse(response.body)
      json.fetch("workflow_runs") { pp json; raise "Couldn't find workflow runs jobs" }
    end
  end

  def latest_ci_log
    statuses = latest_ci_statuses
    raise "no github run jobs logs found, workflows: #{workflows.inspect}" if statuses.empty?

    statuses.each do |s|
      puts "LOG: job: #{s.job_name}, result: #{s.result}, url: #{s.url}"
      print_github_log(s.job_url)
      puts "LOG: job: #{s.job_name}, result: #{s.result}, url: #{s.url}"
    end
  end

  def print_github_log(job_url)
    log_url = "#{job_url}/logs"
    log_download_url = get_github_log_location(log_url)
    request(log_download_url) do |response|
      puts response.body
    end
  end

  def get_github_log_location(log_url)
    # https://api.github.com/repos/puma/puma/actions/jobs/550162360/logs
    # https://docs.github.com/en/rest/reference/actions#download-job-logs-for-a-workflow-run
    request(log_url) do |response|
      if response.code != "302"
        raise "Error getting log location: #{response.body}"
      else
        response['Location']
      end
    end
  end

  def get_github_auth
    auth = ENV['GEM_TRACKER_GITHUB_AUTH']
    unless auth
      raise "GitHub Actions requires GEM_TRACKER_GITHUB_AUTH environment variable set to github_user:token, See documentation to create tokens: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line"
    end
    auth.split(':')
  end

  # Yields a Net::HTTPResponse
  def request(url, &block)
    # puts url
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri.request_uri

      user, token = get_github_auth
      request.basic_auth(user, token)

      yield http.request(request)
    end
  end

  register 'github'
end
