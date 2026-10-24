module AzuCLI
  module DevServer
    # Detects changed files by polling modification times and sizes (no inotify, so it works the same
    # everywhere and needs no dependency). Only the places the app reads from are scanned.
    class Watcher
      DIRECTORIES = ["src", "config", "public/templates"]
      ROOT_FILES  = /\A(shard\.(yml|lock)|\.env.*)\z/

      alias Stamp = {Int64, Int64}

      getter root : String
      @known : Hash(String, Stamp)

      def initialize(@root : String)
        @known = scan
      end

      # Project-relative paths added, changed or removed since the last call.
      def poll : Array(String)
        current = scan
        changed = current.select { |path, stamp| @known[path]? != stamp }.keys
        changed.concat(@known.keys.reject { |path| current.has_key?(path) })
        @known = current
        changed.sort!
      end

      private def scan : Hash(String, Stamp)
        stamps = Hash(String, Stamp).new
        DIRECTORIES.each { |directory| walk(directory, stamps) }
        Dir.each_child(root) { |name| record(name, stamps) if name.matches?(ROOT_FILES) }
        stamps
      end

      private def walk(relative : String, stamps : Hash(String, Stamp)) : Nil
        absolute = File.join(root, relative)
        return unless Dir.exists?(absolute)

        Dir.each_child(absolute) do |name|
          child = File.join(relative, name)
          File.directory?(File.join(root, child)) ? walk(child, stamps) : record(child, stamps)
        end
      rescue File::Error
        # a directory removed while scanning: the next poll sees the result
      end

      private def record(relative : String, stamps : Hash(String, Stamp)) : Nil
        info = File.info(File.join(root, relative))
        stamps[relative] = {info.modification_time.to_unix_ns.to_i64, info.size.to_i64} if info.file?
      rescue File::Error
        # removed between listing and stat
      end
    end
  end
end
