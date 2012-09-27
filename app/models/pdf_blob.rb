class PdfBlob < ActiveRecord::Base
  has_one :pdf_report
  attr_accessible :blob
end
