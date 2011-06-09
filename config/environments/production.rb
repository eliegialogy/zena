# Settings specified here will take precedence over those in config/environment.rb
config.log_level = :info

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Do not change this setting or zafu won't work and EagerPath loader
# will glob *ALL* content in sites directory and try to use it as a template !!!
config.action_view.cache_template_loading            = false

# FIXME: these 2 settings do nothing. Do we need them ?
Cache.perform_caching                                = true
CachedPage.perform_caching                           = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false