class DisbursementRecordsController < ApplicationController
  include Databasedotcom::OAuth2::Helpers

  def index
    @authenticated = authenticated?
    return if !@authenticated

    # Steal the stuff required to instantiate the Restforce client from the Databasedotcom client
    rf_client = Restforce.new :oauth_token => client.oauth_token, :refresh_token => client.refresh_token,
                              :instance_url  => client.instance_url, :client_id     => client.client_id,
                              :client_secret => client.client_secret

    # Retrieve the list of Disbursement Records, handling the possibility of pagination.
    dr_collection = rf_client.query("SELECT Id, Name, OrganizationName__c, EndDate__c, CreatedDate, " +
        "CreatedById, CreatedBy.Name FROM DisbursementRecord__c ORDER BY OrganizationName__c ASC, CreatedDate DESC")
    @disbursement_records = dr_collection.dup.to_a
    while dr_collection.next_page_url
      dr_collection = dr_collection.next_page
      @disbursement_records += dr_collection
    end
  end

  def show
    @authenticated = authenticated?
    return if !@authenticated

    # Steal the stuff required to instantiate the Restforce client from the Databasedotcom client
    rf_client = Restforce.new :oauth_token => client.oauth_token, :refresh_token => client.refresh_token,
                              :instance_url  => client.instance_url, :client_id     => client.client_id,
                              :client_secret => client.client_secret

    # Get the Disbursement Record
    @disbursement_record = rf_client.query("SELECT Id, Name, OrganizationName__c, EndDate__c, CurrencyIsoCode, " +
        "CreatedDate, CreatedById, CreatedBy.Name FROM DisbursementRecord__c WHERE Id = '" + params[:id] + "'")[0]

    @cc_wrappers = DisbursementRecordsHelper.get_line_items(@disbursement_record, "CC", rf_client)

    @summary_data = DisbursementRecordsHelper.get_summary_data(@disbursement_record, rf_client)
    str = render_to_string

    if(params[:pdf])

      pdf = PDFKit.new(str, :page_size => "Letter").to_pdf


      send_data(pdf, {
          :filename => "dr.pdf",
          :type => :pdf,
          :disposition => "attachment"
      })
    else
      render :text => str
    end
  end

  def search
  end
end
