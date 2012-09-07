SalesforceRails::Application.routes.draw do
  get "contact/index"

  #only did symbol this way because of syntax highlighter copy/paste issue
  root 'to'.to_sym => 'welcome#index'
  match "logout" => "welcome#logout"
  match "*rest" => "welcome#index"
end
