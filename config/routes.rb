SalesforceRails::Application.routes.draw do
  resources :pdf_reports
  match "pdf_reports/download/:id" => "pdf_reports#download", as: "download_pdf_report"

  get "disbursement_records/index"
  match "disbursement_records/:id", to: "disbursement_records#show", as: "disbursement_record"

  #only did symbol this way because of syntax highlighter copy/paste issue
  root 'to'.to_sym => 'welcome#index'
  match "logout" => "welcome#logout"
  match "*rest" => "welcome#index"
end
