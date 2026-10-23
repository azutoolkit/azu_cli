require "file_utils"

module GeneratorHelpers
  # Yields a scratch project (shard.yml named `blog`, an Azu-style src/db/schema.cr) and makes it
  # the working directory, which is where the generators look for the project's name and schema.
  def in_generated_project(&)
    dir = File.tempname("azu_generate")
    Dir.mkdir_p(File.join(dir, "src", "db"))
    File.write(File.join(dir, "shard.yml"), "name: blog\nversion: 0.1.0\n")
    File.write(File.join(dir, "src", "db", "schema.cr"), <<-CRYSTAL)
      BlogDB = Azu::CQL.schema :blog_db do
        table :cql_schema_migrations do
          primary :id, Int32
        end
      end
      CRYSTAL
    Dir.cd(dir) { yield dir }
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # Renders a generator into `output_dir` (relative to the project) and returns the content of `file`.
  def rendered(generator, output_dir : String, file : String) : String
    generator.render(File.expand_path(output_dir), force: true, interactive: false)
    File.read(File.join(output_dir, file))
  end
end
