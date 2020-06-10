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

## Tokens

You should set these environment variables in the `.env` file:

* `GEM_TRACKER_TRAVIS_COM_AUTH`: visit your settings page at travis-ci.com to get your token
* `GEM_TRACKER_GITHUB_AUTH`: see https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line

## Documentation

* Travis Ruby Library - https://github.com/travis-ci/travis.rb#ruby-library
