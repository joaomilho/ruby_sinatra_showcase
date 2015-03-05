require 'active_support/core_ext/string/inflections'
module Fidor
  class Resource
    include HTTParty
    # logger  ::Logger.new "httparty.log"
    # debug_output $stderr
    default_timeout(9)


    class << self

      # @return [String] pluralized underscored class name e.g transactions, internal_transfers
      def resource_path
        self.name.demodulize.underscore.pluralize
      end

      # @param [Hash{Symbol=>String}] filter see available filters in the respecting schema file links section
      # @return [Array< Array<Transfer>, String>] Transfers and errors where either one is present
      def find_all(access_token, query_params={})
        res = get("/#{resource_path}", query: query_params,
                                        headers: { 'Authorization' => "Bearer #{access_token}"} )
        if res.is_a?(Hash) && res['error']
          error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
        else
          transfers = res
        end
        [transfers, error]
      end

    end
  end
end