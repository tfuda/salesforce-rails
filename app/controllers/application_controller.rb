class ApplicationController < ActionController::Base
  include Databasedotcom::OAuth2::Helpers
  before_filter :require_authentication

  def rf_client
    # Steal the stuff required to instantiate the Restforce client from the Databasedotcom client
    @rf_client ||= Restforce.new :oauth_token => client.oauth_token, :refresh_token => client.refresh_token,
                              :instance_url => client.instance_url, :client_id => client.client_id,
                              :client_secret => client.client_secret
  end

  def require_authentication
    unless authenticated?
      flash[:error] = "You must log in first before trying to use this feature."
      redirect_to "/auth/salesforce"
    end
  end
end
