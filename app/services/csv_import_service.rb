class CsvImportService
  require "csv"

  REQUIRED_COLUMNS = %w[case_number visa_type petitioner_name].freeze
  OPTIONAL_COLUMNS = %w[beneficiary_name uscis_receipt_number rfe_received_date rfe_deadline notes].freeze
  ALL_COLUMNS = (REQUIRED_COLUMNS + OPTIONAL_COLUMNS).freeze

  attr_reader :results

  def initialize(file:, tenant:, user:)
    @file = file
    @tenant = tenant
    @user = user
    @results = { total: 0, imported: 0, failed: 0, errors: [] }
  end

  def call
    rows = parse_csv
    return @results if rows.nil?

    @results[:total] = rows.size

    rows.each_with_index do |row, index|
      import_row(row, index + 2) # +2 for header row + 0-indexed
    end

    @results
  end

  private

  def parse_csv
    content = @file.read
    begin
      rows = CSV.parse(content, headers: true, header_converters: :downcase)
    rescue CSV::MalformedCSVError => e
      @results[:errors] << { row: 0, message: "Invalid CSV format: #{e.message}" }
      return nil
    end

    # Validate required headers
    missing = REQUIRED_COLUMNS - rows.headers.compact.map(&:strip)
    if missing.any?
      @results[:errors] << { row: 0, message: "Missing required columns: #{missing.join(', ')}" }
      return nil
    end

    rows
  end

  def import_row(row, line_number)
    attrs = {}
    ALL_COLUMNS.each do |col|
      val = row[col]&.strip
      attrs[col] = val if val.present?
    end

    # Validate required fields
    missing = REQUIRED_COLUMNS.select { |col| attrs[col].blank? }
    if missing.any?
      @results[:failed] += 1
      @results[:errors] << { row: line_number, message: "Missing required fields: #{missing.join(', ')}" }
      return
    end

    rfe_case = RfeCase.new(
      attrs.merge(
        tenant: @tenant,
        created_by: @user
      )
    )

    if rfe_case.save
      @results[:imported] += 1
    else
      @results[:failed] += 1
      @results[:errors] << { row: line_number, message: rfe_case.errors.full_messages.join(", ") }
    end
  end
end
