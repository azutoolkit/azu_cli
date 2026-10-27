require "../../generators/session"

module AzuCLI
  module Commands
    module Session
      # The session initializers the generators write for a project, rendered in memory, and the backend of a file
      # that is one of them as written. `session:clear` deletes data on that answer, so it trusts no other file:
      # an initializer someone edited (a comment, a guard, a different store) is not read at all, and the command
      # asks for `--backend` instead of guessing what the code does.
      module GeneratedInitializer
        PATH = AzuCLI::Generate::Session::INITIALIZER

        # {backend, source} for every file it recognises: what `azu session:setup --backend <backend>` writes for
        # `project`, and what `azu generate auth` writes (a cookie store), now and before its first line, the
        # marker, was added.
        def self.renderings(project : String) : Array({String, String})
          list = AzuCLI::Generate::Session::BACKENDS.map do |backend|
            {backend, rendered(AzuCLI::Generate::Session.new(project: project, backend: backend))}
          end
          auth = rendered(AzuCLI::Generate::Auth.new)
          list << {"cookie", auth}
          list << {"cookie", auth.lchop(auth.lines(chomp: false).first)}
        end

        # The backend of `source` when it is one of `renderings` as written (CRLF line ends and trailing
        # whitespace at the end of the file aside), else nil.
        def self.backend(source : String, renderings : Array({String, String})) : String?
          normalized = normalize(source)
          renderings.find { |_, rendering| normalize(rendering) == normalized }.try(&.first)
        end

        def self.normalize(source : String) : String
          source.gsub("\r\n", "\n").rstrip
        end

        private def self.rendered(tree : Teeplate::FileTree) : String
          entry = tree.rendered_file_entries.find { |file| file.path == PATH }
          raise "#{tree.class} has no #{PATH} template" unless entry
          String.build { |io| entry.write_to(io) }
        end
      end
    end
  end
end
