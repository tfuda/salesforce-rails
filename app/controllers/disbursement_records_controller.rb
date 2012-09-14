class DisbursementRecordsController < ApplicationController
  include Databasedotcom::OAuth2::Helpers

  def index
    @authenticated = authenticated?
    return if !@authenticated

    # Steal the stuff required to instantiate the Restforce client from the Databasedotcom client
    rf_client = Restforce.new :oauth_token => client.oauth_token, :refresh_token => client.refresh_token,
                              :instance_url => client.instance_url, :client_id => client.client_id,
                              :client_secret => client.client_secret

    # Retrieve the list of Disbursement Records, handling the possibility of pagination.
    dr_query = "SELECT Id, Name, OrganizationName__c, EndDate__c, CreatedDate, " +
        "CreatedById, CreatedBy.Name FROM DisbursementRecord__c"
    if params[:startDate] || params[:endDate]
      dr_query += " WHERE"
      if params[:startDate]
        startTime = Time.parse(params[:startDate])
        dr_query += " CreatedDate >= " + startTime.xmlschema
        dr_query += " AND" if params[:endDate]
      end
      if params[:endDate]
        endTime = Time.parse(params[:endDate])
        dr_query += " CreatedDate < " + endTime.xmlschema
      end
    end
    dr_query += " ORDER BY OrganizationName__c ASC, CreatedDate DESC"
    dr_collection = rf_client.query(dr_query)
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
                              :instance_url => client.instance_url, :client_id => client.client_id,
                              :client_secret => client.client_secret

    # Get the DisbursementReportDescriptor object
    @dr_descriptors = []
    params[:selected_ids].each do |dr_id|
      @dr_descriptors.append(DisbursementRecordsHelper::DisbursementReportDescriptor.new(dr_id, rf_client))
    end

    str = render_to_string

    if (params[:pdf])
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
