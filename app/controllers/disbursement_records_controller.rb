require 'delayed_job'

class DisbursementRecordsController < ApplicationController
  before_filter :require_authentication

  def index
    @authenticated = authenticated?
    @me = me if authenticated?
    @selected_org_name = nil unless @selected_org_name
    @selected_org_name = params[:selected_org_name]
    @start_date = Time.now - 7.days unless @start_date
    @start_date = Time.local(params[:start_date][:year], params[:start_date][:month], params[:start_date][:day], 0, 0 ,0) if params[:start_date]
    @end_date = nil unless @end_date
    @end_date = Time.local(params[:end_date][:year], params[:end_date][:month], params[:end_date][:day], 23, 59, 59) if params[:end_date]

    # Retrieve the list of Disbursement Records, handling the possibility of pagination.
    dr_query = "SELECT Id, Name, OrganizationName__c, EndDate__c, CreatedDate, " +
        "CreatedById, CreatedBy.Name FROM DisbursementRecord__c"
    dr_query += " WHERE CreatedDate >= " + @start_date.xmlschema
    dr_query += " AND CreatedDate <= " + @end_date.xmlschema if @end_date != nil
    dr_query += " AND OrganizationName__c = '" + @selected_org_name + "'" if (@selected_org_name && @selected_org_name != '')
    dr_query += " ORDER BY OrganizationName__c ASC, CreatedDate DESC"
    dr_collection = rf_client.query(dr_query)
    @disbursement_records = dr_collection.dup.to_a
    while dr_collection.next_page_url
      dr_collection = dr_collection.next_page
      @disbursement_records += dr_collection
    end

    # Used to build a select list on the page
    @org_names = [['--All--', '']]
    @org_names |= @disbursement_records.map {|dr| dr.OrganizationName__c}.uniq
  end

  def show
    if(params[:render_as_html])
      @dr_descriptors = params[:selected_ids].collect {|dr_id|
        DisbursementRecordsHelper::DisbursementReportDescriptor.new(dr_id, rf_client)
      }
      render :layout => 'pdf_disbursement_reports'
      return
    end
    PdfReport.transaction do
      report = PdfReport.new(:status => PdfReport::Status::Queued, :dr_list => params[:selected_ids].join(','))
      report.save!
      job = Delayed::Job.enqueue PDFGeneration.new(report.id,params[:selected_ids],rf_client)
      report.delayed_job_id = job.id
      report.save!
      flash[:notice] = 'Report has been enqueued'
    end
    redirect_to :controller => 'pdf_reports', :action => 'index'
  end

  def render_pdf(ids,rf_client)
    # Get the DisbursementReportDescriptor object
    @dr_descriptors = ids.collect {|dr_id|
      DisbursementRecordsHelper::DisbursementReportDescriptor.new(dr_id, rf_client)
    }
    PDFKit.new(render_to_string(:template => 'disbursement_records/show', :layout => 'pdf_disbursement_reports'))
  end

  class PDFGeneration
    def initialize(report_id, ids, rf_client)
      @report_id = report_id
      @ids = ids
      @rf_client = rf_client
    end
    def perform
      kit = DisbursementRecordsController.new.render_pdf(@ids,@rf_client)
      PdfBlob.transaction do
        blob = PdfBlob.new
        blob.blob = kit.to_pdf
        blob.save!
        report = PdfReport.find(@report_id)
        report.pdf_blob_id = blob.id
        report.status = PdfReport::Status::Done
        report.save!
      end
    end
  end
end
