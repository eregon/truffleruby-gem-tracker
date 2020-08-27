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
    begin
      client = new_travis_client
      repo = client.find_one(Travis::Client::Repository, gem.name)
      branch = repo.last_on_branch(gem.branch)

      branch.jobs.each do |j|
        if matching_config?(j.config)
          url = "#{base_url}/#{@gem.name}/jobs/#{j.id}"
          statuses << {status: j.color, version: j.config["rvm"], url: url, time: j.started_at}
        end
      end
    rescue Travis::Client::Error => e
      statuses << {status: nil, message: "Status Error: #{e.message}"}
    end
    if statuses.empty?
      statuses << {name: @gem.name, status: nil, message: "no truffleruby travis jobs found"}
    end
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
          puts "LOG: version: #{j.config["rvm"]}, status: #{j.color}, url: #{url}"
          puts j.log.colorized_body
          puts "LOG: version: #{j.config["rvm"]}, status: #{j.color}, url: #{url}"
        end
      end
    rescue Travis::Client::Error => e
      puts "LOG ERROR:"
      puts e.message
    end
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
