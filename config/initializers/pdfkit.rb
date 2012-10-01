PDFKit.configure do |config|
  if(Rails.env.development?)
    config.wkhtmltopdf = File.join('C:', 'wkhtmltopdf', 'wkhtmltopdf.exe')
  else
    config.wkhtmltopdf = File.join(Rails.root, 'bin', 'wkhtmltopdf')
  end
  config.default_options = {
    :page_size => 'Letter',
    :orientation => 'Landscape',
    :margin_top => '0.5in',
    :margin_right => '0.5in',
    :margin_bottom => '0.7in',
    :margin_left => '0.5in'
  }
end