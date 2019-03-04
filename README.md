# Mastermind

Mastermind is a CLI framework.  It's purpose is to help build, configure, and run
command line tools.

Mastermind is designed for flexibility, extensibility, minimal dependencies.

## My devious plot cannot wait!  Tell me your secrets!

If you want to jump right into using Mastermind, head over to the [wiki][wiki].

## Flexibility

Mastermind is written in Ruby and, therefore, provides first-class citizenship
to that language and uses Ruby's syntax and semantics in its configuration files.

Mastermind looks for and evaluates `.masterplan` files recursively up the file
tree until it reaches the root of your project, if defined, or your home directory,
if it's not.  Additionally, it always looks for and attempts to load a `.masterplan`
file in your home directory, if one exists.

In this way, configuration for your tools can live where it makes the most sense
for it to live with as much or as little duplication as you deem necessary.

See [Writing Masterplans][writing-masterplans] for more on their structure and
semantics.

Mastermind makes up for the lack of flexibility in its configuration with full
flexibility in its planfiles.  Which brings us to...

## Extensibility

Mastermind is designed from the outset to provide a means of extending its planfile
formats through custom `Loader`s.  In fact, Mastermind's own `PlanfileLoader` is
the first of such loaders.  You can specify your own file extensions and provide
your own loaders as needed.

As long as the objects returned by your loader quack like a `Plan`, Mastermind
won't fuss at them.  After all, you can't take over the world if your busy mucking
about in the details!

Obviously, it'd be a bit difficult to write your plan files in an entirely separate
language, but there's nothing stopping you from delegating actions to another
executable or even writing some C code to call into something else alltogether.

If you are writing your plans in Ruby, Mastermind provides `CLI::Mastermind::Plan::Interface`
which you can include in your plans to provide the basic `Plan` interface.

## Minimal Dependencies

Mastermind only has one dependency, Shopify's excelent [cli-ui project][cli-ui].
Mastermind doesn't require that you load it in your Gemfile or add anything to
your project's configuration files.

## Usage

### The `mastermind` Executable

Mastermind's own help is pretty straightforward:

    Usage: mastermind [--help, -h] [--plans[ PATTERN], --tasks[ PATTERN], -T [PATTERN], -P [PATTERN] [PLAN[, PLAN[, ...]]] -- [PLAN ARGUMENTS]
        -h, --help                       Display this help
        -P, -T, --plans [PATTERN],       Display plans.  Optional pattern is used to filter the returned plans.
            --tasks

Any arguments specified after `--` are passed as-is down to the executed plan.
You can then process those arguments however you like or ignore them completely!

Unlike Rake and other, similar, tools that allow you to run multiple tasks in
parallel, _Mastermind is designed to run only one task at a time_.  Specifying
multiple plan names on the command line is how you walk down the tree to a
specific plan.

If you don't provide enough information to Mastermind to walk to an executable
plan, Mastermind will provide you with a list of available options to choose.

For more information on how to use and configure Mastermind, check out the
[wiki][wiki].

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

Mastermind uses itself to run tests and build new versions.  Run `bin/rspec` to
run tests.  To install this gem onto your local machine, run `exe/mastermind gem install`
To release a new version, update the version number in `version.rb`, and then run
`exe/mastermind gem release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chall8908/cli-mastermind.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[wiki]: https://github.com/chall8908/cli-mastermind/wiki
[writing-masterplans]: https://github.com/chall8908/cli-mastermind/wiki/Writing-Masterplans
[cli-ui]: https://github.com/shopify/cli-ui
