# Advanced Ruby Example using Sinatra

This repo contains a step by step guide on how to develop an Fidor app.
See the git log for the steps.

## Dependencies

* Ruby 2+

## Usage

Create and edit the settings

  cp settings.yml.default settings.yml

Install required gems and run

  bundle install
  ruby example.rb

  # or run on different port than :4567 provided by WEBrick
  ruby example.rb -p 3004

## Configuration

In case you downloaded this project from the Fidor AppManager, all the
configuration should have already been set up for you. In case you
retrieved this example from another source, you'll need to open the
`settings.yml` file and fill in the configuration values at the top of the
file. You will be able to find out the values in the AppManager, create
a new App and use the configuration from the new App's detail page.
