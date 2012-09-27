class CreatePdfReports < ActiveRecord::Migration
  def change
    create_table :pdf_reports do |t|
      t.text :dr_list
      t.text :status
      t.references :delayed_job
      t.references :pdf_blob

      t.timestamps
    end
  end
end
