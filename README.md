# Advanced Ruby Example using Sinatra

This repo contains a step by step guide on how to develop a Fidor app using the
sinatra micro-framework.

See the git commit log for the steps. The code will improve and some odd looking
parts are there to show common problems(and solutions to them) in API-Client
Software. We did not use a bunch of magic helper libraries from the very start,
to show the road you will have to go. The decision whether to use external libs
or building your own ones is up to you. We'll leave lots of room for improvements in
here.

Non-Ruby developers are also welcome to read because the problems we face
(API-client wise) are common, no matter what framework or language you
are using. Ruby is really readable, so give it a try.

## Dependencies

* Ruby 2+

## Usage

Create and edit the settings

```sh
cp settings.yml.default settings.yml
```

Install required gems and run

```sh
bundle install
bundle exec ruby example.rb

# or run on different port than :4567 provided by WEBrick
bundle exec ruby example.rb -p 3004
```

## Configuration

In case you downloaded this project from the Fidor AppManager, all the
configuration should have already been set up for you. In case you
retrieved this example from another source, you'll need to open the
`settings.yml` file and fill in the configuration values at the top of the
file. You will be able to find out the values in the AppManager, create
a new App and use the configuration from the new App's detail page.
