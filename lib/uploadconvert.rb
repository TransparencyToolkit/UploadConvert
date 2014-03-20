require 'json'
require 'docsplit'
require 'crack'

class UploadConvert

  def initialize(input)
    @input = input
    @output = ""
    @text = ""
  end

  # Sends the document to the appropriate method
  def handleDoc
    if @input.include? "http"
      `wget #{@input}`
      path = @input.split("/")
      @input = path[path.length-1].chomp.strip
      handleDoc
    elsif @input.include? ".pdf"
      pdfTojson
    elsif @input.include? ".xml"
      xmlTojson(File.read(@input))
    end
  end

  # Convert XML files to JSONs
  def xmlTojson(xmlin)
    xml = Crack::XML.parse(xmlin)
    JSON.pretty_generate(xml)
  end

  # Convert PDFs to JSON
  def pdfTojson
    # Extract and clean text
    @text = detectPDFType

    # Extract metadata and generate output                                                                                          
    extractMetadataPDF
    outhash = Hash.new
    @metadata.each{|k, v| outhash[k] = v}
    outhash[:text] = @text
    outhash[:input] = @input
    @output = JSON.pretty_generate(outhash)
  end

  # Use embedded fonts to detect the type of PDF
  def detectPDFType
    out = `pdffonts #{@input}`.split("\n")
    if out.length > 4
      return embedPDF
    else
      # return ocrPDF
    end
  end

  # Extract text from embedded text PDFs
  def embedPDF
    begin
      Docsplit.extract_text(@input, :ocr => false)
      outfile = @input.split(".pdf")
      text = File.read(outfile[0]+".txt")
    
      # Clean up text and delete file
      File.delete(outfile[0]+".txt")
      cleanPDF(text)
    rescue
    end
  end

  # OCR PDFs and turn that text into a JSON
  def ocrPDF
    # Extract individual pages
    Docsplit.extract_images(@input)
    
    # OCR
    docs = Dir["*.png"]
    Docsplit.extract_text(@input, :ocr => true, :output => 'text')
    outfile = @input.split(".")
    text = File.read("text/" + outfile[0] + ".txt")

    # Clean up text and files
    File.delete("text/" + outfile[0]+".txt")
    Dir.delete("text")
    docs.each do |d|
      File.delete(d)
    end
    cleanPDF(text)
  end

  # Removes numbers from edges of legal documents
  def cleanPDF(text)
    text.gsub!(/\r?\n/, "\n")
    text.each_line do |l|
      lflag = 0
      (1..28).each do |i|
        if l == i.to_s+"\n"
          lflag = 1
        end
      end

      if lflag != 1 && l
        @text += l
      end
    end
    
    return @text
  end

  # Extract PDF metadata
  def extractMetadataPDF
    @metadata = Hash.new
    @metadata[:author] = Docsplit.extract_author(@input)
    @metadata[:creator] =  Docsplit.extract_creator(@input)
    @metadata[:producer] = Docsplit.extract_producer(@input)
    @metadata[:title] = Docsplit.extract_title(@input)
    @metadata[:subject] = Docsplit.extract_subject(@input)
    @metadata[:date] = Docsplit.extract_date(@input)
    @metadata[:keywords] = Docsplit.extract_keywords(@input)
    @metadata[:length] = Docsplit.extract_length(@input)
    return @metadata
  end
end
