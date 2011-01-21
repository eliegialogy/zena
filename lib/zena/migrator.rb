module Zena
  class Migrator < ActiveRecord::Migrator
    class << self

      def migrate(migrations_path, brick_name, target_version = nil)
        case
          when target_version.nil?              then up(migrations_path, brick_name, target_version)
          when current_version(brick_name) > target_version then down(migrations_path, brick_name, target_version)
          else                                       up(migrations_path, brick_name, target_version)
        end
      end

      def up(migrations_path, brick_name, target_version = nil)
        self.new(:up, migrations_path, brick_name, target_version).migrate
      end

      def down(migrations_path, brick_name, target_version = nil)
        self.new(:down, migrations_path, brick_name, target_version).migrate
      end

      def old_bricks_info_table_name
        ActiveRecord::Base.table_name_prefix + "bricks_info" + ActiveRecord::Base.table_name_suffix
      end

      def bricks_info_table_name
        if ActiveRecord::Base.connection.tables.include?(old_bricks_info_table_name)
          old_bricks_info_table_name
        else
          schema_migrations_table_name
        end
      end

      def get_all_versions(brick_name)
        ActiveRecord::Base.connection.select_values("SELECT version FROM #{bricks_info_table_name} WHERE brick #{brick_name ? '=' : 'IS'} #{ActiveRecord::Base.connection.quote(brick_name)}").map(&:to_i).sort
      end

      def current_version(brick_name)
        sm_table = bricks_info_table_name
        if ActiveRecord::Base.connection.table_exists?(sm_table)
          get_all_versions(brick_name).max || 0
        else
          0
        end
      end

      def init_bricks_migration_table

        # Migrate from 0.11 (rails 1.2.3) to 0.13 (rails 2.3.4)
        connection = ActiveRecord::Base.connection
        sm_table = ActiveRecord::Migrator.schema_migrations_table_name
        si_table = ActiveRecord::Base.table_name_prefix + 'schema_info' + ActiveRecord::Base.table_name_suffix
        if !connection.tables.include?(sm_table) && connection.tables.include?(old_bricks_info_table_name)
          v_brick, v_schema = 0, 0
          connection.select_all("SELECT version FROM #{old_bricks_info_table_name} WHERE brick = 'zena'", "Bricks_info fix").each do |record|
            v_brick = record['version'].to_i
          end
          if v_brick > 0
            connection.select_all("SELECT version FROM #{si_table}", "Bricks_info fix").each do |record|
              v_schema = record['version'].to_i
            end
            if v_schema < v_brick
              connection.execute "UPDATE schema_info SET version = #{v_brick}"
              connection.execute "DROP TABLE #{old_bricks_info_table_name}"
              connection.initialize_schema_migrations_table
            end
          end
        end

        if !connection.tables.include?(sm_table)
          connection.initialize_schema_migrations_table
        end

        unless ActiveRecord::Base.connection.columns(schema_migrations_table_name).map{|c| c.name}.include?('brick')
          ActiveRecord::Migration.announce("adding 'brick' scope to schema_migrations")
          ActiveRecord::Migration.add_column   schema_migrations_table_name, :brick, :string
          ActiveRecord::Migration.remove_index schema_migrations_table_name,
                                                     :name => 'unique_schema_migrations'
          ActiveRecord::Migration.add_index    schema_migrations_table_name, [:brick,:version],
                                                     :name => 'unique_schema_migrations', :unique => true
        end
      end
    end

    def initialize(direction, migrations_path, brick_name, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless ActiveRecord::Base.connection.supports_migrations?
      self.class.init_bricks_migration_table
      @direction, @migrations_path, @brick_name, @target_version = direction, migrations_path, brick_name, target_version
    end

    def migrated
      @migrated_versions ||= self.class.get_all_versions(@brick_name)
    end

    private
      def record_version_state_after_migrating(version)
        sm_table = self.class.bricks_info_table_name

        @migrated_versions ||= []
        if down?
          @migrated_versions.delete(version.to_i)
          ActiveRecord::Base.connection.update("DELETE FROM #{sm_table} WHERE version = '#{version}' AND brick = #{ActiveRecord::Base.connection.quote(@brick_name)}")
        else
          @migrated_versions.push(version.to_i).sort!
          ActiveRecord::Base.connection.insert("INSERT INTO #{sm_table} (version, brick) VALUES ('#{version}',#{ActiveRecord::Base.connection.quote(@brick_name)})")
        end
      end
  end
end
