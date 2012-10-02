class WelcomeController < ApplicationController
  def index
    @authenticated = authenticated?
    @me = me if authenticated?
  end

  def logout
    client.logout if authenticated?
    render 'index'
  end
end
