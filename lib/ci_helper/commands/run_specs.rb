# frozen_string_literal: true

module CIHelper
  module Commands
    class RunSpecs < BaseCommand
      def call
        return if job_files.empty?

        create_and_migrate_database! if with_database?
        create_and_migrate_clickhouse_database! if with_clickhouse?
        execute("bundle exec rspec #{Shellwords.join(job_files)}")
        return 0 unless split_resultset?

        execute("mv coverage/.resultset.json coverage/resultset.#{job_index}.json")
      end

      private

      def env
        :test
      end

      def job_files
        p("PATCHED!!!!!!")
        all_files = path.glob("spec/**/*_spec.rb")
        all_files_count = all_files.count
        heavy_files = []
        std_files   = []

        all_files.each do |file|
          relative_path = file.relative_path_from(path).to_s
          if heavy_specs_paths.any? { |pattern| File.fnmatch?(pattern, relative_path) }
            heavy_files << file
          else
            std_files << file
          end
        end

        sorted_files =
          std_files.map { |x| [x.size, x.relative_path_from(path).to_s] }.sort.map(&:last)
        (sorted_files + heavy_files).reverse.select.with_index do |_file, index|
          (index % job_count) == (job_index - 1)
        end
      end

      def heavy_specs_paths
        %w[
          spec/requests/admin/customers/orders_spec.rb
          spec/requests/admin/customers/orders/download_spec.rb
          spec/requests/admin/orders/download_spec.rb
          spec/requests/admin/orders/index_spec.rb
          spec/requests/admin/hung_withdraws/index_spec.rb
          spec/requests/admin/reports/*
        ]
      end

      def job_index
        @job_index ||= options[:node_index]&.to_i || 1
      end

      def job_count
        @job_count ||= options[:node_total]&.to_i || 1
      end

      def with_database?
        boolean_option(:with_database)
      end

      def with_clickhouse?
        boolean_option(:with_clickhouse)
      end

      def split_resultset?
        boolean_option(:split_resultset)
      end
    end
  end
end
