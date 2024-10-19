class GemTracker::Status
  attr_reader :gem, :result, :url, :time, :job_url
  attr_accessor :job_name

  ALLOWED_RESULTS = [:success, :failure, :in_progress, :unknown, :no_recent_run]

  def initialize(gem:, result:, job_name:, url:, time:, job_url: nil)
    raise "result must be one of #{ALLOWED_RESULTS}" unless ALLOWED_RESULTS.include?(result) or Exception === result
    @gem = gem
    @result = result
    @job_name = job_name
    @url = url
    @time = time
    @job_url = job_url
  end
end
