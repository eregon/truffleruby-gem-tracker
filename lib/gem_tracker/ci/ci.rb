class GemTracker::CI
  ALL = {}

  def self.register(name)
    ALL[name] = self
  end

  def self.create(gem, name)
    ALL.fetch(name).new(gem)
  end

  attr_reader :gem

  def initialize(gem)
    @gem = gem
  end

  def latest_ci_statuses
    raise NotImplementedError
  end

  def latest_ci_log
    raise NotImplementedError
  end
end

require_relative 'github'
require_relative 'travis'
