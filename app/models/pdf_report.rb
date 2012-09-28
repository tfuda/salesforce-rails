class PdfReport < ActiveRecord::Base
  class Status
    Queued = 'Queued'
    Done = 'Done'
  end
  belongs_to :pdf_blob, :dependent => :destroy
  attr_accessible :dr_list, :job_id, :status
end
