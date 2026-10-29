require "html"
require "random/secure"

module AzuCLI
  module Generate
    # One editable partial feeds desktop and mobile navigation. Only collection GET
    # routes belong here: member routes need an id and writes must never be links.
    module Navigation
      PARTIAL = "public/templates/helpers/_sections.jinja"
      ANCHOR  = "{# azu:sections:end #}"

      def self.register(root : String, label : String, route : String) : Nil
        path = File.join(root, PARTIAL)
        return unless File.file?(path) # Older/custom layouts opt in by adding the partial.
        return unless route.matches?(/\A\/[a-z][a-z0-9_\/-]*\z/)

        before = File.read(path)
        return if before.includes?(%(href="#{route}")) || before.includes?(%(href='#{route}'))
        unless before.includes?(ANCHOR)
          Logger.warn("Navigation unchanged: add #{ANCHOR} to #{PARTIAL} to register generated sections.")
          return
        end

        entry = %(<li><a href="#{route}" data-nav-link><span class="size-2 rounded-full bg-primary/60" aria-hidden="true"></span>#{HTML.escape(label)}</a></li>)
        after = before.sub(ANCHOR, "#{entry}\n#{ANCHOR}")
        # Replace in the same directory so a failed write cannot truncate custom links.
        temporary = "#{path}.#{Random::Secure.hex(6)}.tmp"
        begin
          File.write(temporary, after)
          File.chmod(temporary, File.info(path).permissions)
          File.rename(temporary, path)
        ensure
          File.delete(temporary) if File.exists?(temporary)
        end
      end
    end
  end
end
