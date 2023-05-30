require_relative 'status'
require_relative 'ci/ci'

class GemTracker::Gem
  attr_reader :name, :ci, :workflows, :branch, :expect, :pattern, :search_last_n_builds

  def self.from_hash(hash)
    GemTracker::Gem.new(**hash.transform_keys(&:to_sym))
  end

  def initialize(name:, ci: 'github', workflows: nil, branch: nil, expect: 'pass', pattern: 'truffleruby',
      search_last_n_builds: 1)
    @name = name
    @workflows = workflows
    @branch = branch
    @expect = expect.to_sym
    @pattern = pattern
    @search_last_n_builds = search_last_n_builds

    @ci = GemTracker::CI.create(self, ci)
  end

  def repo_name
    File.basename(name)
  end

  def latest_ci_statuses
    @ci.latest_ci_statuses
  end

  def latest_ci_log
    @ci.latest_ci_log
  end
end
