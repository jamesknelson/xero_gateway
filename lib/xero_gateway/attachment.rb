module XeroGateway
  class Attachment
    class Error < RuntimeError; end
    class NoGatewayError < Error; end

    # Xero::Gateway associated with this invoice.
    attr_accessor :gateway

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors

    # accessible fields
    attr_accessor :attachment_id, :file_name, :url, :mime_type, :content_length

    def initialize(params = {})
      @errors ||= []

      params.each do |k,v|
        self.send("#{k}=", v)
      end
    end

    def self.from_xml(attachment_element, gateway = nil, options = {})
      attachment = Attachment.new(options.merge({:gateway => gateway}))
      attachment_element.children.each do |element|
        case(element.name)
          when "AttachmentId" then attachment.attachment_id = element.text
          when "FileName" then attachment.file_name = element.text
          when "Url" then attachment.url = element.text
          when "MimeType" then attachment.mime_type = element.text
          when "ContentLength" then attachment.content_length = element.text.to_i
        end
      end
      attachment
    end # from_xml
  end
end
