# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
SalesforceRails::Application.initialize!

Delayed::Worker.max_attempts = 1
