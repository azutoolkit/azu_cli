module AzuCLI
  module DevServer
    # What a changed file asks `azu dev` to do, weakest first.
    enum Action
      # Nothing to do (a static asset, an editor's temporary file, a file the app never reads).
      Ignore
      # Templates are read from disk: the running app reloads them itself, so there is nothing to rebuild.
      Templates
      # The app reads the file when it boots (an `.env` file): restart without compiling.
      Restart
      # Source and configuration are compiled in or read at boot: compile, then restart.
      Rebuild
    end

    # Maps a project-relative path to the `Action` a change to it needs.
    module Classifier
      EDITOR_FILES = /(~|\.sw[a-p]|\.tmp)\z|\A(\.#|#.*#\z)|\A4913\z/
      ENV_FILE     = /\A\.env(\.(?!example\z)[\w-]+)?\z/

      def self.classify(path : String) : Action
        base = File.basename(path)
        return Action::Ignore if base.matches?(EDITOR_FILES)
        return Action::Templates if path.starts_with?("public/templates/")
        return Action::Rebuild if path.starts_with?("src/") || path.starts_with?("config/") || {"shard.yml", "shard.lock"}.includes?(path)
        return Action::Restart if !path.includes?('/') && base.matches?(ENV_FILE)

        Action::Ignore
      end
    end

    # The files that changed since the last plan, grouped by what they need.
    struct Plan
      getter action : Action
      getter files : Array(String)

      def initialize(@action : Action, @files : Array(String))
      end
    end

    # Collects changes and releases them once the files have been quiet for `debounce`: an editor that
    # saves several files, or a branch switch, then costs one rebuild instead of one per file.
    class Batcher
      @pending = Hash(String, Action).new
      @last_change : Time::Instant?

      def initialize(@debounce : Time::Span)
      end

      def add(paths : Array(String), now : Time::Instant) : Nil
        relevant = paths.map { |path| {path, Classifier.classify(path)} }.reject { |(_, action)| action.ignore? }
        return if relevant.empty?

        relevant.each { |(path, action)| @pending[path] = action }
        @last_change = now
      end

      def pending? : Bool
        !@pending.empty?
      end

      # The plan, once nothing changed for the debounce time; nil before that (or when nothing is pending).
      def take(now : Time::Instant) : Plan?
        last = @last_change
        return unless last && pending? && now - last >= @debounce

        plan = Plan.new(@pending.values.max, @pending.keys.sort!)
        @pending.clear
        @last_change = nil
        plan
      end
    end
  end
end
