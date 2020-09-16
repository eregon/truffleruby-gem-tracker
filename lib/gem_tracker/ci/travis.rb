require 'travis/client'

class GemTracker::Travis < GemTracker::CI
  def new_travis_client
    raise NotImplementedError
  end

  def base_url
    raise NotImplementedError
  end

  def latest_ci_statuses
    statuses = []
    client = new_travis_client
    repo = client.find_one(Travis::Client::Repository, gem.name)
    branch = repo.last_on_branch(gem.branch)

    branch.jobs.each do |j|
      if matching_config?(j.config)
        url = "#{base_url}/#{@gem.name}/jobs/#{j.id}"
        statuses << GemTracker::Status.new(gem: gem, result: status_to_result(j), job_name: j.config["rvm"], url: url, time: j.started_at)
      end
    end

    raise "no truffleruby travis jobs found for #{gem.name}" if statuses.empty?
    statuses
  end

  def latest_ci_log
    puts "LOGS"
    begin
      client = new_travis_client
      repo = client.find_one(Travis::Client::Repository, @gem.name)
      branch = repo.last_on_branch(gem.branch)

      branch.jobs.each do |j|
        if matching_config?(j.config)
          url = "#{base_url}/#{@gem.name}/jobs/#{j.id}"
          puts "LOG: job: #{j.config["rvm"]}, result: #{status_to_result(j)}, url: #{url}"
          puts j.log.colorized_body
          puts "LOG: job: #{j.config["rvm"]}, result: #{status_to_result(j)}, url: #{url}"
        end
      end
    rescue Travis::Client::Error => e
      puts "LOG ERROR:"
      puts e.message
    end
  end

  def status_to_result(job)
    { green: :success, yellow: :in_progress, red: :failure }.fetch(job.color.to_sym)
  end

  def matching_config?(config)
    config.include?("rvm") && config["rvm"].is_a?(String) && config["rvm"].include?(gem.pattern)
  end
end

class GemTracker::TravisOrg < GemTracker::Travis
  def new_travis_client
    Travis::Client.new
  end

  def base_url
    'https://travis-ci.org'
  end

  register 'travis'
end

class GemTracker::TravisCom < GemTracker::Travis
  def new_travis_client
    Travis::Client.new(:uri => Travis::Client::COM_URI, :access_token => get_travis_com_auth)
  end

  def base_url
    'https://travis-ci.com'
  end

  def get_travis_com_auth
    auth = ENV['GEM_TRACKER_TRAVIS_COM_AUTH']
    unless auth
      raise "travis-ci.com logs/statuses require GEM_TRACKER_TRAVIS_COM_AUTH environment variable set to token, visit your settings page at travis-ci.com to get your token"
    end
    auth
  end

  register 'traviscom'
end
