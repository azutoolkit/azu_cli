module AzuCLI
  module Helpers
    private def render_initialize(params : Array(String))
      String.build do |str|
        str << "def initialize("

        params.each do |param|
          field, type = param.split(":")
          str << "@#{field.downcase} : #{type.camelcase}, "
        end

        str << ")"
      end
    end

    private def render_field(params : Array(String))
      String.build do |str|
        params.each do |param|
          method, field, type = param.split(":")
          str << "#{method.downcase} #{field.downcase} : #{type.camelcase}"
        end
      end
    end
  end
end
