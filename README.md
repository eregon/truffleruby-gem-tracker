# TruffleRuby Gem Tracker

The TruffleRuby Gem Tracker is designed to track the status of gems CIs testing TruffleRuby.

## Status

See [GitHub Actions runs](https://github.com/eregon/truffleruby-gem-tracker/actions).

## Usage

### List latest gem statuses

```bash
bin/gem_tracker statuses [--parallel]
```

### List latest single gem status

```bash
bin/gem_tracker status concurrent-ruby
```

### Print latest job log

```bash
bin/gem_tracker log concurrent-ruby
```

## Tokens

You should set these environment variables in the `.env` file:

* `GEM_TRACKER_TRAVIS_COM_AUTH`: visit your settings page at travis-ci.com to get your token
* `GEM_TRACKER_GITHUB_AUTH`: see [GitHub Documentation](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line)

## Documentation

* Travis Ruby Library - https://github.com/travis-ci/travis.rb#ruby-library

## GitHub Searches

* [GitHub Actions](https://github.com/search?q=truffleruby-head+language%3AYAML+path%3A.github&type=Code)
* [.travis.yml](https://github.com/search?q=truffleruby-head+filename%3A.travis.yml+path%3A%2F&type=Code)

## Contributing

The list of gems is maintained in [gems.yml](gems.yml).
