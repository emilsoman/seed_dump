require "true"
require "clip"

class SeedDump
  module DumpMethods

    def initialize
      @opts = {}
      @ar_options = {}
      @indent = ""
      @models = []
      @last_record = []
      @seed_rb = ""
      @id_set_string = ""
    end

    def setup(env)
      # config
      @opts['verbose'] = env["VERBOSE"].true? || env['VERBOSE'].nil?
      @opts['debug'] = env["DEBUG"].true?
      @opts['with_id'] = env["WITH_ID"].true?
      @opts['timestamps'] = env["TIMESTAMPS"].true? || env["TIMESTAMPS"].nil?
      @opts['no-data'] = env['NO_DATA'].true?
      @opts['skip_callbacks'] = env['SKIP_CALLBACKS'].true?
      @opts['models']  = env['MODELS'] || (env['MODEL'] ? env['MODEL'] : "")
      @opts['file']    = env['FILE'] || "#{Rails.root}/db/seeds.rb"
      @opts['append']  = (env['APPEND'].true? && File.exists?(@opts['file']) )
      @opts['max']     = env['MAX'] && env['MAX'].to_i > 0 ? env['MAX'].to_i : nil
      @ar_options      = env['LIMIT'].to_i > 0 ? { :limit => env['LIMIT'].to_i } : {}
      @indent          = " " * (env['INDENT'].nil? ? 2 : env['INDENT'].to_i)
      @opts['models']  = @opts['models'].split(',').collect {|x| x.underscore.singularize.camelize }
      @opts['create_method']  = env['CREATE_METHOD'] || 'create!'
      @opts['csv']  = (env['CSV'].to_s == 'true')
    end

    def log(msg)
      puts msg if @opts['debug']
    end

    def models
      @models
    end

    def last_record
      @last_record
    end

    def dump_attribute(a_s, r, k, v)
      pushed = false
      if v.is_a?(BigDecimal)
        v = v.to_s
      else
        v = attribute_for_inspect(r,k)
      end

      unless k == 'id' && !@opts['with_id']
        if (!(k == 'created_at' || k == 'updated_at') || @opts['timestamps'])
          a_s.push("#{k.to_sym.inspect} => #{v}")
          pushed = true
        end
      end
      pushed
    end

    def attribute_names(row)
      names = []
      row.attributes.each do |attr_name, value|
        next if skip_attribute?(attr_name)
        names.push attr_name
      end
      return names.join(',')
    end

    def attribute_values(row)
      values = []
      row.attributes.each do |attr_name, value|
        next if skip_attribute?(attr_name)
        values.push value
      end
      return values.join(',')
    end

    def skip_attribute?(attr_name)
      unless attr_name == 'id' && !@opts['with_id']
        if (!(attr_name == 'created_at' || attr_name == 'updated_at') || @opts['timestamps'])
          return false
        end
      end
      return true
    end

    def dump_model(model, csv)
      if csv
        dump_model_csv(model)
      else
        dump_model_ruby(model)
      end
    end

    def dump_model_csv(model)
      @id_set_string = ''
      @last_record = []
      create_hash = ""
      options = ''
      rows = []
      arr = nil
      unless @opts['no-data']
        arr = model.all
        arr.limit(@ar_options[:limit]) if @ar_options[:limit]
      end
      arr = arr.empty? ? [model.new] : arr

      arr.each_with_index { |r,i|
        rows.push(attribute_names(r)) if (i == 0)
        rows.push(attribute_values(r))
      }

      if @opts['max']
        splited_rows = rows.each_slice(@opts['max']).to_a
        maxsarr = []
        splited_rows.each do |sr|
          maxsarr << "\n#{model}\n" << sr.join("\n") << "\n"
        end
        maxsarr.join('')
      else
        "\n#{model}\n" << rows.join("\n") << "\n"
      end
    end

    def dump_model_ruby(model)
      @id_set_string = ''
      @last_record = []
      create_hash = ""
      options = ''
      rows = []
      arr = nil
      unless @opts['no-data']
        arr = model.all
        arr.limit(@ar_options[:limit]) if @ar_options[:limit]
      end
      arr = arr.empty? ? [model.new] : arr

      arr.each_with_index { |r,i|
        attr_s = [];
        r.attributes.each do |k,v|
          pushed_key = dump_attribute(attr_s,r,k,v)
          @last_record.push k if pushed_key
        end
        rows.push "#{@indent}{ " << attr_s.join(', ') << " }"
      }

      if @opts['max']
        splited_rows = rows.each_slice(@opts['max']).to_a
        maxsarr = []
        splited_rows.each do |sr|
          maxsarr << "\n#{model}.#{@opts['create_method']}([\n" << sr.join(",\n") << "\n]#{options})\n"
        end
        maxsarr.join('')
      else
        "\n#{model}.#{@opts['create_method']}([\n" << rows.join(",\n") << "\n]#{options})\n"
      end

    end

    def dump_models
      Rails.application.eager_load!

      @seed_rb = ""

      models = ActiveRecord::Base.descendants.select do |model|
                 (model.to_s != 'ActiveRecord::SchemaMigration') && \
                 (@opts['models'].empty? || \
                  @opts['models'].include?(model.to_s)) && \
                  model.table_exists?
               end

      models.sort! { |a, b| a.to_s <=> b.to_s }

      models.each do |model|
        if !model.abstract_class
          puts "Adding #{model} seeds." if @opts['verbose']

          if @opts['skip_callbacks']
            @seed_rb << "#{model}.reset_callbacks :save\n"
            @seed_rb << "#{model}.reset_callbacks :create\n"
            puts "Callbacks are disabled." if @opts['verbose']
          end

          @seed_rb << dump_model(model, @opts['csv']) << "\n\n"
        else
          puts "Skipping abstract class #{model}..." if @opts['verbose']
        end
      end

      @seed_rb
    end

    def write_file
      File.open(@opts['file'], (@opts['append'] ? "a" : "w")) { |f|
        f << "#{@seed_rb}"
      }
    end

    #override the rails version of this function to NOT truncate strings
    def attribute_for_inspect(r,k)
      value = r.attributes[k]

      if value.is_a?(String) && value.length > 50
        "#{value}".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      else
        value.inspect
      end
    end

    def output
      @seed_rb
    end

    def run(env)
      setup env

      puts "Appending seeds to #{@opts['file']}." if @opts['append']
      dump_models

      puts "Writing #{@opts['file']}."
      write_file

      puts "Done."
    end
  end
end
