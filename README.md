# GemTracker

The Gem Tracker is designed to track the status of Gems from external CI systems.

## Installation

After checking out the repo, run `bin/setup` to install dependencies. 

To install this gem onto your local machine, run `bundle exec rake install`.

## Usage

*list latest gem statuses*
`bundle exec exe/gem_tracker statuses`

*list latest single gem status*
`bundle exec exe/gem_tracker status ruby-concurrency/concurrent-ruby`

*print latest job log*
`bundle exec exe/gem_tracker log ruby-concurrency/concurrent-ruby`