require "fileutils"
require "pathname"

module SolidQueueLite
  class Install
    INITIALIZER_RELATIVE_PATH = "config/initializers/solid_queue_lite.rb"

    def initialize(host_root: Rails.root, stdout: $stdout)
      @host_root = Pathname(host_root)
      @stdout = stdout
    end

    def run!(migrate: false)
      install_migrations
      install_initializer
      run_migrations if migrate
      print_next_steps(migrate: migrate)
    end

    private

      attr_reader :host_root, :stdout

      def install_migrations
        with_env("FROM" => "solid_queue_lite") do
          invoke_task("railties:install:migrations")
        end
      end

      def install_initializer
        if initializer_path.exist?
          say "Skipped #{relative_initializer_path}; file already exists"
          return
        end

        FileUtils.mkdir_p(initializer_path.dirname)
        initializer_path.write(initializer_template)
        say "Created #{relative_initializer_path}"
      end

      def run_migrations
        invoke_task("db:migrate")
      end

      def print_next_steps(migrate:)
        say ""
        say "Solid Queue Lite install complete."

        unless migrate
          say "Run `bin/rails db:migrate` or rerun with `bin/rails solid_queue_lite:install MIGRATE=1`."
        end

        say "Mount the engine inside your host application's auth boundary, for example:"
        say ""
        say "authenticate :user, ->(user) { user.admin? } do"
        say "  mount SolidQueueLite::Engine => \"/ops/jobs\""
        say "end"
        say ""
        say "Schedule `SolidQueueLite::TelemetrySamplerJob` in `config/recurring.yml` if you want historical charts."
      end

      def invoke_task(task_name)
        task = Rake::Task[task_name]
        task.reenable
        task.invoke
      end

      def with_env(updates)
        previous_values = updates.transform_values { |_,| nil }

        updates.each do |key, value|
          previous_values[key] = ENV[key]
          ENV[key] = value
        end

        yield
      ensure
        previous_values.each do |key, value|
          ENV[key] = value
        end
      end

      def initializer_path
        host_root.join(relative_initializer_path)
      end

      def relative_initializer_path
        INITIALIZER_RELATIVE_PATH
      end

      def initializer_template
        <<~RUBY
          SolidQueueLite.configure do |config|
            config.tenant_scope = lambda do |relation|
              relation
            end

            config.telemetry_backfill_on_boot = true
          end
        RUBY
      end

      def say(message)
        stdout.puts(message)
      end
  end
end
