require 'yaml'
require 'gem_tracker/gem'

module GemTracker
  DATA = YAML.load_file(File.expand_path('../../gems.yml', __dir__))

  def self.convert_to_gems(gems_data)
    h = {}
    gems_data.each do |g|
      gem = GemTracker::Gem.from_hash(g)
      h[gem.name] = gem
    end
    h
  end

  GEMS = convert_to_gems(DATA['gems'])
end

