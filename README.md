# Mastermind

Mastermind is a CLI toolkit.  It's purpose is to help build, configure, and run
command line tools.

Mastermind is designed for flexibility, extensibility, and minimal dependencies.

## Flexibility

Mastermind is written in Ruby and, therefore, provides first-class citizenship
to that language and uses Ruby's syntax and semantics in its primary configuration
files.

Mastermind looks for and executes `.masterplan` files recursively up the file tree
until it reaches the root of your project, if defined, or your home directory,
if it's not.  Additionally, it always looks for and attempts to load a `.masterplan`
file in your home directory, if one exists.

In this way, configuration for your tools can live where it makes the most sense
for it to live with as much or as little duplication as you deem necessary.

See [Writing Masterplans][#writing-masterplans] for more on their structure and semantics.

Mastermind makes up for the lack of language flexibility in its configuration
with full flexibility in its planfiles.  Which brings us to...

## Extensibility

Mastermind is designed from the outset to provide means of extending its planfile
formats through custom `Loader`s.  In fact, Mastermind's own `PlanfileLoader` is
the first of such loaders.  You can specify your own file extensions and provide
your own loaders as needed.

As long as the objects returned by your loader quack like a `Plan`, Mastermind
won't fuss at them.  After all, you can't take over the world if your busy mucking
about in the details!

## Minimal Dependencies

Mastermind only has one dependency, Shopify's excelent [cli-ui project][cli-ui].
It doesn't require that you load it in your Gemfile or do anything in particular.
All you need to be able to do is run its executable and Mastermind does the rest.

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
parallel, Mastermind is designed to run only one task at a time.  Specifying
multiple plans on the command line is how you walk down the tree to a specific
plan.

### Writing Masterplans

`.masterplan` files use a minimal DSL to configure Mastermind and load planfiles.
Some of these commands have sensible defaults designed to keep configuration to
a minimum.

#### Masterplan DSL

##### `project_root [directory]`

Specifies the root of your project.  Must be specified to prevent Mastermind
from scanning more of your filesystem than it needs to.  The easiest way to
do this is to just specify it in a `.masterplan` file in the actual root of
your project.

Aliased as `at_project_root`.  The argument defaults to the directory of the
current `.masterplan`.

##### `plan_files [directory]`

Specifies that plan files exist in the given directory.  Mastermind will search
this directory for any files that end in a supported extension and mark them
for loading.  By default, Mastermind only supports files with a `.plan` extension.

Aliased as `has_plan_files`. The argument defaults to a `plans` directory in
the same directory as the current `.masterplan`.

##### `plan_file filename[, filename[, ...]]`

Instructs Mastermind to load the planfiles located at the given filenames.

##### `configure attribute [value] [&block]`

Used to set arbitrary configuration options.  When a configuration option is
set in multiple `.masterplan` files, the "closest" one to your invocation wins.
In other words, since Mastermind reads `.masterplan` files starting in your
current directory and working it's way "up" the hierarchy, the first `.masterplan`
that specifies a configuration option "wins".

When provided a block, the value is computed the first time the option is called
for.  The block runs in the context of the `Configuration` object built up by
all the loaded `.masterplan` files, so it has access to all previously set
configuration options.

The block is only executed once.  After that, the value is cached so that it
doesn't need to be recomputed.

If both a block and a value are given, the block is ignored and only the value
is stored.

##### `see_also filename`

Instructs Mastermind to also load the configuration specified in `filename`.
This file does _not_ have to be named `.masterplan` but _does_ have to conform
to the syntax outlined here.

### Writing Planfiles

By default, planfiles use a very simple DSL that will feel familiar to anyone
that's ever used Rake.  The biggest difference between Rake (and similar tools)
and Mastermind is that Mastermind has no support for dependent tasks or parallel
tasks.  If your workflow requires either of those things, Mastermind is probably
not the tool you want to use.  Or, rather, not the _only_ tool you want to use.

#### Planfile DSL

##### `plot name &block`

Creates a Plan that contains children with the given `name`.  This is similar
to the `namespace` command in a Rakefile.  The Plans created inside the block
are added as children of this Plan.

##### `description text`

Provides a description for the next Plan created.  Plans created with `plot`
can also have descriptions.

##### `plan name &block`

Creates a Plan with the given name and sets the given block as its action.
This block is passed the arguments from the command line and is run as a Plan.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

Mastermind uses itself to run tests and build new versions.  Run `exe/mastermind rspec`
to run tests.  To install this gem onto your local machine, run `exe/mastermind gem install`
To release a new version, update the version number in `version.rb`, and then run
`exe/mastermind gem release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chall8908/cli-mastermind.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[cli-ui]: https://github.com/shopify/cli-ui
