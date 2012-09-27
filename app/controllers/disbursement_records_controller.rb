class DisbursementRecordsController < ApplicationController
  include Databasedotcom::OAuth2::Helpers
  before_filter :require_authentication

  def index
    start_date = Time.now - 7.days
    end_date = nil
    if params[:start_date]
      start_date = Time.local(params[:start_date][:year], params[:start_date][:month], params[:start_date][:day], 0, 0 ,0)
    end
    if params[:end_date]
      end_date = Time.local(params[:end_date][:year], params[:end_date][:month], params[:end_date][:day], 23, 59, 59)
    end

    # Retrieve the list of Disbursement Records, handling the possibility of pagination.
    dr_query = "SELECT Id, Name, OrganizationName__c, EndDate__c, CreatedDate, " +
        "CreatedById, CreatedBy.Name FROM DisbursementRecord__c"
    dr_query += " WHERE CreatedDate >= " + start_date.xmlschema
    dr_query += " AND CreatedDate <= " + end_date.xmlschema if end_date != nil
    dr_query += " ORDER BY OrganizationName__c ASC, CreatedDate DESC"
    dr_collection = rf_client.query(dr_query)
    @disbursement_records = dr_collection.dup.to_a
    while dr_collection.next_page_url
      dr_collection = dr_collection.next_page
      @disbursement_records += dr_collection
    end
  end

  def show
    # Get the DisbursementReportDescriptor object
    @dr_descriptors = params[:selected_ids].collect {|dr_id|
      DisbursementRecordsHelper::DisbursementReportDescriptor.new(dr_id, rf_client)
    }

    respond_to do |format|
      format.html { return }
      format.pdf {
        self.formats = [:html]
        str = render_to_string
        pdf = PDFKit.new(str, :page_size => "Letter").to_pdf
        send_data pdf, { :filename => "dr.pdf", :type => :pdf, :disposition => "attachment" }
      }
    end
  end

  def search
  end
end
