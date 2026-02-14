class ExportService
  attr_reader :rfe_case, :format

  def initialize(rfe_case, format: :pdf)
    @rfe_case = rfe_case
    @format = format.to_sym
  end

  def call
    case format
    when :pdf then generate_pdf
    when :docx then generate_docx
    when :zip then generate_zip
    else raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  def filename
    safe_number = rfe_case.case_number.gsub(/[^a-zA-Z0-9_-]/, "_")
    "RFE_Response_#{safe_number}_#{Date.current}.#{format}"
  end

  def content_type
    case format
    when :pdf then "application/pdf"
    when :docx then "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    when :zip then "application/zip"
    end
  end

  private

  def sections_with_drafts
    @sections_with_drafts ||= rfe_case.rfe_sections.ordered.includes(:draft_responses).map do |section|
      draft = section.draft_responses.order(version: :desc).first
      { section: section, draft: draft }
    end
  end

  def exhibits
    @exhibits ||= rfe_case.exhibits.ordered
  end

  def tenant
    @tenant ||= rfe_case.tenant
  end

  def attorney_name
    rfe_case.assigned_attorney&.full_name || "Attorney of Record"
  end

  def response_content(draft)
    return "No draft response available." unless draft
    draft.final_content.presence || draft.edited_content.presence || draft.ai_generated_content.presence || "No content."
  end

  # ===========================================================================
  # PDF Generation (Prawn)
  # ===========================================================================

  def generate_pdf
    pdf = Prawn::Document.new(
      page_size: "LETTER",
      margin: [72, 72, 72, 72], # 1 inch margins
      info: {
        Title: "RFE Response - #{rfe_case.case_number}",
        Author: tenant.name,
        Creator: "RFE Ready",
        CreationDate: Time.current
      }
    )

    pdf_cover_page(pdf)
    pdf.start_new_page
    pdf_table_of_contents(pdf)
    pdf.start_new_page
    pdf_response_sections(pdf)
    pdf_exhibit_list(pdf)
    pdf_page_numbers(pdf)

    pdf.render
  end

  def pdf_cover_page(pdf)
    pdf.move_down 120

    pdf.text tenant.name.upcase, size: 18, style: :bold, align: :center
    pdf.move_down 8
    pdf.text "Response to Request for Evidence", size: 14, align: :center
    pdf.move_down 40

    pdf.stroke_horizontal_rule
    pdf.move_down 20

    details = [
      ["Case Number:", rfe_case.case_number],
      ["USCIS Receipt #:", rfe_case.uscis_receipt_number || "N/A"],
      ["Visa Type:", rfe_case.visa_type],
      ["Petitioner:", rfe_case.petitioner_name],
      ["Beneficiary:", rfe_case.beneficiary_name || "N/A"],
      ["RFE Received:", rfe_case.rfe_received_date&.strftime("%B %d, %Y") || "N/A"],
      ["Response Deadline:", rfe_case.rfe_deadline&.strftime("%B %d, %Y") || "N/A"],
      ["Prepared By:", attorney_name],
      ["Date:", Date.current.strftime("%B %d, %Y")]
    ]

    pdf.table(details, position: :center, width: 400) do |t|
      t.cells.borders = []
      t.cells.padding = [4, 8]
      t.columns(0).font_style = :bold
      t.columns(0).width = 160
    end

    pdf.move_down 40
    pdf.stroke_horizontal_rule
    pdf.move_down 20

    pdf.text "CONFIDENTIAL — ATTORNEY WORK PRODUCT", size: 10, align: :center, style: :italic
  end

  def pdf_table_of_contents(pdf)
    pdf.text "TABLE OF CONTENTS", size: 14, style: :bold
    pdf.move_down 16
    pdf.stroke_horizontal_rule
    pdf.move_down 16

    # Response sections
    pdf.text "I. Response Sections", size: 12, style: :bold
    pdf.move_down 8

    sections_with_drafts.each_with_index do |item, idx|
      section = item[:section]
      label = "#{idx + 1}. #{section.title}"
      label += " (#{section.cfr_reference})" if section.cfr_reference.present?
      pdf.text label, size: 11, indent_paragraphs: 20
      pdf.move_down 4
    end

    if exhibits.any?
      pdf.move_down 12
      pdf.text "II. Exhibit List", size: 12, style: :bold
      pdf.move_down 8

      exhibits.each do |exhibit|
        pdf.text "Exhibit #{exhibit.label}: #{exhibit.title}", size: 11, indent_paragraphs: 20
        pdf.move_down 4
      end
    end
  end

  def pdf_response_sections(pdf)
    pdf.text "RESPONSE TO REQUEST FOR EVIDENCE", size: 14, style: :bold, align: :center
    pdf.move_down 20

    sections_with_drafts.each_with_index do |item, idx|
      section = item[:section]
      draft = item[:draft]

      pdf.start_new_page if idx > 0

      # Section heading
      heading = "#{idx + 1}. #{section.title}"
      pdf.text heading, size: 13, style: :bold
      pdf.move_down 4

      if section.cfr_reference.present?
        pdf.text "Reference: #{section.cfr_reference}", size: 10, style: :italic, color: "666666"
        pdf.move_down 8
      end

      pdf.stroke_horizontal_rule
      pdf.move_down 12

      # Response content
      content = response_content(draft)
      pdf.text content, size: 11, leading: 4, align: :justify
      pdf.move_down 20
    end
  end

  def pdf_exhibit_list(pdf)
    return if exhibits.empty?

    pdf.start_new_page
    pdf.text "EXHIBIT LIST", size: 14, style: :bold, align: :center
    pdf.move_down 20

    table_data = [["Exhibit", "Title", "Description"]]
    exhibits.each do |exhibit|
      table_data << [
        exhibit.label,
        exhibit.title,
        exhibit.description.to_s.truncate(120)
      ]
    end

    pdf.table(table_data, header: true, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "E8E8E8"
      t.cells.padding = [6, 8]
      t.cells.borders = [:bottom]
      t.cells.border_width = 0.5
      t.columns(0).width = 60
      t.columns(1).width = 160
    end
  end

  def pdf_page_numbers(pdf)
    pdf.number_pages "Page <page> of <total>",
      at: [pdf.bounds.right - 150, -4],
      size: 9,
      align: :right,
      start_count_at: 1
  end

  # ===========================================================================
  # DOCX Generation (Caracal)
  # ===========================================================================

  def generate_docx
    tempfile = Tempfile.new(["rfe_export", ".docx"])
    begin
      Caracal::Document.save(tempfile.path) do |docx|
        docx_cover_page(docx)
        docx_table_of_contents(docx)
        docx_response_sections(docx)
        docx_exhibit_list(docx)
      end
      File.binread(tempfile.path)
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  def docx_cover_page(docx)
    firm_name = tenant&.name || "Law Firm"
    case_details = [
      ["Case Number", rfe_case.case_number],
      ["USCIS Receipt #", rfe_case.uscis_receipt_number || "N/A"],
      ["Visa Type", rfe_case.visa_type],
      ["Petitioner", rfe_case.petitioner_name],
      ["Beneficiary", rfe_case.beneficiary_name || "N/A"],
      ["RFE Received", rfe_case.rfe_received_date&.strftime("%B %d, %Y") || "N/A"],
      ["Response Deadline", rfe_case.rfe_deadline&.strftime("%B %d, %Y") || "N/A"],
      ["Prepared By", attorney_name],
      ["Date", Date.current.strftime("%B %d, %Y")]
    ]

    docx.p do
      text firm_name.upcase, bold: true, size: 36, align: :center
    end
    docx.p do
      text "Response to Request for Evidence", size: 28, align: :center
    end
    docx.p
    docx.hr

    case_details.each do |label, value|
      docx.p do
        text "#{label}: ", bold: true, size: 22
        text value.to_s, size: 22
      end
    end

    docx.p
    docx.hr
    docx.p do
      text "CONFIDENTIAL — ATTORNEY WORK PRODUCT", italic: true, size: 20, align: :center
    end
    docx.page
  end

  def docx_table_of_contents(docx)
    docx.h2 "Table of Contents"
    docx.p

    docx.h3 "I. Response Sections"
    sections_with_drafts.each_with_index do |item, idx|
      section = item[:section]
      label = "#{idx + 1}. #{section.title}"
      label += " (#{section.cfr_reference})" if section.cfr_reference.present?
      docx.p label
    end

    if exhibits.any?
      docx.p
      docx.h3 "II. Exhibit List"
      exhibits.each do |exhibit|
        docx.p "Exhibit #{exhibit.label}: #{exhibit.title}"
      end
    end

    docx.page
  end

  def docx_response_sections(docx)
    docx.h1 "Response to Request for Evidence"
    docx.p

    sections_with_drafts.each_with_index do |item, idx|
      section = item[:section]
      draft = item[:draft]

      docx.page if idx > 0

      docx.h2 "#{idx + 1}. #{section.title}"

      if section.cfr_reference.present?
        docx.p do
          text "Reference: #{section.cfr_reference}", italic: true, size: 20, color: "666666"
        end
      end

      docx.hr
      docx.p

      content = response_content(draft)
      # Split content into paragraphs for proper DOCX formatting
      content.split(/\n\n+/).each do |paragraph|
        paragraph = paragraph.strip
        next if paragraph.empty?
        docx.p paragraph.gsub(/\n/, " "), size: 22
      end

      docx.p
    end
  end

  def docx_exhibit_list(docx)
    return if exhibits.empty?

    docx.page
    docx.h1 "Exhibit List"
    docx.p

    docx.table exhibits.map { |e| [e.label, e.title, e.description.to_s.truncate(120)] } do
      border_color "999999"
      cell_style rows[0], bold: true, background: "E8E8E8"
    end
  end

  # ===========================================================================
  # ZIP Package (Response document + Exhibit files)
  # ===========================================================================

  def generate_zip
    require "zip"

    safe_number = rfe_case.case_number.gsub(/[^a-zA-Z0-9_-]/, "_")
    folder_name = "RFE_Response_#{safe_number}"

    # Generate the response document as PDF (default for package)
    response_doc_format = :pdf
    response_doc = self.class.new(rfe_case, format: response_doc_format).call
    response_filename = "#{folder_name}.#{response_doc_format}"

    buffer = Zip::OutputStream.write_buffer do |zip|
      # Add the response document
      zip.put_next_entry("#{folder_name}/#{response_filename}")
      zip.write(response_doc)

      # Add exhibit files
      exhibits.includes(:rfe_document).each do |exhibit|
        next unless exhibit.rfe_document&.file&.attached?

        doc = exhibit.rfe_document
        ext = File.extname(doc.filename.to_s)
        safe_title = exhibit.title.to_s.gsub(/[^a-zA-Z0-9_\- ]/, "").strip
        safe_title = "Document" if safe_title.blank?
        exhibit_filename = "#{exhibit.label} - #{safe_title}#{ext}"

        zip.put_next_entry("#{folder_name}/Exhibits/#{exhibit_filename}")
        zip.write(doc.file.download)
      end
    end

    buffer.string
  end
end
