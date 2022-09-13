require 'dotenv/load'
require 'yaml'
require_relative 'gem'

module GemTracker
  DATA = YAML.load_file(File.expand_path('../../gems.yml', __dir__))

  def self.convert_to_gems(gems_data)
    h = {}
    gems_data.each do |g|
      gem = GemTracker::Gem.from_hash(g)
      raise "Duplicate gem: #{gem.name}" if h.key?(gem.name)
      h[gem.name] = gem
    end
    h
  end

  GEMS = convert_to_gems(DATA['gems'])
end

