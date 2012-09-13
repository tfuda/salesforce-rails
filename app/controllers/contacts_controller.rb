class ContactsController < ApplicationController
  include Databasedotcom::OAuth2::Helpers

  def index
    @authenticated = authenticated?
    return if !@authenticated
    client.materialize("Contact")
    Contact.client = client
    @contacts = Contact.query("Id != null ORDER BY LastName, FirstName LIMIT 50")
  end
end
