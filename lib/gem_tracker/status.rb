class GemTracker::Status
  attr_reader :gem, :result, :url, :time, :job_url
  attr_accessor :job_name

  ALLOWED_RESULTS = [:success, :failure, :in_progress, :unknown]

  def initialize(gem:, job_name:, result:, url:, time:, job_url: nil)
    raise "result must be one of #{ALLOWED_RESULTS}" unless ALLOWED_RESULTS.include?(result)
    @gem = gem
    @job_name = job_name
    @result = result
    @url = url
    @time = time
    @job_url = job_url
  end
end
