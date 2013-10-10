# Mock Rails.application.eager_load! and define some
# Rails models for use in specs.
class Rails
  def self.application
    self
  end

  def self.eager_load!
    @already_called ||= false

    if !@already_called
      Object.const_set('Sample', Class.new(ActiveRecord::Base))

      Object.const_set('AbstractSample', Class.new(ActiveRecord::Base))
      AbstractSample.abstract_class = true

      Object.const_set('ChildSample', Class.new(AbstractSample))

      Object.const_set('NoTableModel', Class.new(ActiveRecord::Base))

      Object.const_set('Nested', Module.new)
      Nested.const_set('Sample', Class.new(ActiveRecord::Base))

      @already_called = true
    end
  end
end

module Helpers
  def create_db
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define(:version => 1) do
      create_table 'child_samples', :force => true do |t|
        t.string   'name'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end

      create_table 'samples', :force => true do |t|
        t.string   'string'
        t.text     'text'
        t.integer  'integer'
        t.float    'float'
        t.decimal  'decimal'
        t.datetime 'datetime'
        t.datetime 'timestamp'
        t.time     'time'
        t.date     'date'
        t.binary   'binary'
        t.boolean  'boolean'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end
    end
  end

  def create_db_with_sane_data
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define(:version => 1) do
      create_table 'students', :force => true do |t|
        t.string   'name'
        t.integer   'roll_number'
        t.boolean   'genius'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end
    end

    Object.const_set('Student', Class.new(ActiveRecord::Base))

    Student.create!([
      {:name => 'User1', :roll_number => 10, :genius => false},
      {:name => 'User1', :roll_number => 10, :genius => false},
      {:name => 'Emil', :roll_number => 15, :genius => true}
    ])
  end
end
