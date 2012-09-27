PDFKit.configure do |config|
  if(Rails.env.development?)
    config.wkhtmltopdf = File.join('C:', 'wkhtmltopdf', 'wkhtmltopdf.exe')
  else
    config.wkhtmltopdf = File.join(Rails.root, 'bin', 'wkhtmltopdf')
  end
end