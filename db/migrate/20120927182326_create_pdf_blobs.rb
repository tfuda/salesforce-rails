class CreatePdfBlobs < ActiveRecord::Migration
  def change
    create_table :pdf_blobs do |t|
      t.binary :blob

      t.timestamps
    end
  end
end
