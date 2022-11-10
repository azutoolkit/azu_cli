require "ecr"

module Jennifer
  module Generators
    abstract class Base
      getter name : String, args : Array(String)

      def initialize(@args : Array(String))
        @name = @args[0]
      end

      def render
        File.write(file_path, to_s)
        notify
      end

      private abstract def file_path : String

      private def notify
        puts "#{file_path} was successfully created."
      end

      private def definitions
        @args[1..-1]
      end
    end
  end
end
