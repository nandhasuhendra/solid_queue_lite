require "json"

module SolidQueueLite
  module ApproximateCounter
    module_function

    def count(relation)
      adapter_name = relation.connection.adapter_name.downcase

      case adapter_name
      when /postgres/
        simple_relation?(relation) ? postgresql_table_estimate(relation) : postgresql_explain_estimate(relation)
      when /mysql/, /trilogy/
        simple_relation?(relation) ? mysql_table_estimate(relation) : mysql_explain_estimate(relation)
      when /sqlite/
        relation.except(:select, :order).count
      else
        raise NotImplementedError, "Unsupported adapter for approximate counts: #{relation.connection.adapter_name}"
      end.to_i
    end

    def simple_relation?(relation)
      relation.where_clause.empty? &&
        relation.joins_values.empty? &&
        relation.left_outer_joins_values.empty? &&
        relation.group_values.empty? &&
        relation.having_clause.empty? &&
        relation.limit_value.nil? &&
        relation.offset_value.nil? &&
        !relation.distinct_value
    end

    def postgresql_table_estimate(relation)
      relation.connection.select_value(<<~SQL.squish)&.to_i
        SELECT COALESCE(reltuples, 0)
        FROM pg_class
        WHERE oid = #{relation.connection.quote(relation.table_name)}::regclass
      SQL
    end

    def mysql_table_estimate(relation)
      relation.connection.select_value(<<~SQL.squish)&.to_i
        SELECT COALESCE(table_rows, 0)
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = #{relation.connection.quote(relation.table_name)}
      SQL
    end

    def postgresql_explain_estimate(relation)
      plan_json = relation.connection.select_value(
        "EXPLAIN (FORMAT JSON) #{relation.except(:select, :order).to_sql}"
      )

      JSON.parse(plan_json).dig(0, "Plan", "Plan Rows")
    end

    def mysql_explain_estimate(relation)
      explain_json = relation.connection.select_value(
        "EXPLAIN FORMAT=JSON #{relation.except(:select, :order).to_sql}"
      )

      extract_mysql_row_estimate(JSON.parse(explain_json))
    end

    def extract_mysql_row_estimate(node)
      case node
      when Hash
        return node["rows_produced_per_join"] if node.key?("rows_produced_per_join")
        return node["rows_examined_per_scan"] if node.key?("rows_examined_per_scan")
        return node["rows"] if node.key?("rows")

        node.each_value do |value|
          estimate = extract_mysql_row_estimate(value)
          return estimate if estimate
        end
      when Array
        node.each do |value|
          estimate = extract_mysql_row_estimate(value)
          return estimate if estimate
        end
      end

      nil
    end
  end
end
