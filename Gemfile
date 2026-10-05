# frozen_string_literal: true

source "https://rubygems.org"

gem "jekyll", "~> 4.4"
gem "jekyll-text-theme", "~> 2.2"

group :jekyll_plugins do
  gem "jekyll-paginate"
  gem "jekyll-sitemap"
  gem "jekyll-feed"
end

gem "html-proofer", "~> 5.0", group: :test

platforms :windows, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.2.0", :platforms => [:windows]
