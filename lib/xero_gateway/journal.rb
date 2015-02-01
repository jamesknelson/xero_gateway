module XeroGateway
  class Journal
    include Dates

    class Error < RuntimeError; end
    class NoGatewayError < Error; end

    GUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/ unless defined?(GUID_REGEX)

    LINE_AMOUNT_TYPES = {
      "Inclusive" =>        'Invoice lines are inclusive tax',
      "Exclusive" =>        'Invoice lines are exclusive of tax (default)',
      "NoTax"     =>        'Invoices lines have no tax'
    } unless defined?(LINE_AMOUNT_TYPES)

    # Xero::Gateway associated with this invoice.
    attr_accessor :gateway

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors

    # Represents whether the journal lines have been downloaded when getting from GET /API.XRO/2.0/Journals
    attr_accessor :journal_lines_downloaded

    # accessible fields
    attr_accessor :journal_id, :journal_date, :journal_number, :journal_lines, :reference, :created_date_utc, :source_id, :source_type

    def initialize(params = {})
      @errors ||= []

      # Check if the line items have been downloaded.
      @journal_lines_downloaded = (params.delete(:journal_lines_downloaded) == true)

      params.each do |k,v|
        self.send("#{k}=", v)
      end

      @journal_lines ||= []
    end

    def ==(other)
      ['journal_id', 'journal_number', 'journal_lines', 'reference'].each do |field|
        return false if send(field) != other.send(field)
      end

      ["date"].each do |field|
        return false if send(field).to_s != other.send(field).to_s
      end
      return true
    end

    def journal_lines_downloaded?
      @journal_lines_downloaded
    end

    # If line items are not downloaded, then attempt a download now (if this record was found to begin with).
    def journal_lines
      if journal_lines_downloaded?
        @journal_lines

      else
        # We can't create journals, so this must be an existing journal
        # Let's attempt to download the journal_line records (if there is a gateway)

        response = @gateway.get_journal(journal_id)
        raise JournalNotFoundError, "Journal with ID #{journal_id} not found in Xero." unless response.success? && response.journal.is_a?(XeroGateway::Journal)

        @journal_lines = response.journal.journal_lines
        @journal_lines_downloaded = true

        @journal_lines
      end
    end

    def self.from_xml(journal_element, gateway = nil, options = {})
      journal = Journal.new(options.merge({:gateway => gateway}))
      journal_element.children.each do |element|
        case(element.name)
          when "JournalID" then journal.journal_id = element.text
          when "JournalDate" then journal.journal_date = parse_date(element.text)
          when "JournalNumber" then journal.journal_number = element.text
          when "SourceID" then journal.source_id = element.text
          when "SourceType" then journal.source_type = element.text
          when "Reference" then journal.reference = element.text
          when "CreatedDateUTC" then journal.created_date_utc = parse_date_time_utc(element.text)
          when "JournalLines" then element.children.each {|journal_line| journal.journal_lines_downloaded = true; journal.journal_lines << JournalLine.from_xml(journal_line) }
        end
      end
      journal
    end # from_xml
  end
end
