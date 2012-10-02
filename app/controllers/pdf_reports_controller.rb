class PdfReportsController < ApplicationController
  # GET /pdf_reports
  # GET /pdf_reports.json
  def index
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_reports = PdfReport.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @pdf_reports }
    end
  end

  # GET /pdf_reports/1
  # GET /pdf_reports/1.json
  def show
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @pdf_report }
    end
  end

  # GET /pdf_reports/new
  # GET /pdf_reports/new.json
  def new
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @pdf_report }
    end
  end

  # GET /pdf_reports/1/edit
  def edit
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.find(params[:id])
  end

  # POST /pdf_reports
  # POST /pdf_reports.json
  def create
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.new(params[:pdf_report])

    respond_to do |format|
      if @pdf_report.save
        format.html { redirect_to @pdf_report, notice: 'Pdf report was successfully created.' }
        format.json { render json: @pdf_report, status: :created, location: @pdf_report }
      else
        format.html { render action: "new" }
        format.json { render json: @pdf_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /pdf_reports/1
  # PUT /pdf_reports/1.json
  def update
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.find(params[:id])

    respond_to do |format|
      if @pdf_report.update_attributes(params[:pdf_report])
        format.html { redirect_to @pdf_report, notice: 'Pdf report was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @pdf_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /pdf_reports/1
  # DELETE /pdf_reports/1.json
  def destroy
    @authenticated = authenticated?
    @me = me if authenticated?
    @pdf_report = PdfReport.find(params[:id])
    @pdf_report.destroy

    respond_to do |format|
      format.html { redirect_to pdf_reports_url }
      format.json { head :no_content }
    end
  end

  def download
    @authenticated = authenticated?
    @me = me if authenticated?
    report = PdfReport.find(params[:id])
    send_data(report.pdf_blob.blob, {
        :filename => "dr.pdf",
        :type => :pdf,
        :disposition => "attachment"
    })
  end
end
