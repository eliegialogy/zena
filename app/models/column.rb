class Column < ActiveRecord::Base
  attr_accessor :import_result
  include RubyLess
  include Property::StoredColumn
  TYPES_FOR_FORM   = %w{string datetime integer float}

  INDICES_FOR_FORM = %w{string ml_string datetime integer float}

  FIELD_INDICES = []

  belongs_to :role
  before_validation :set_defaults

  validates_presence_of :role
  validates_uniqueness_of :name, :scope => :site_id
  validate :name_not_in_models

  after_save :expire_vclass_cache
  after_destroy :expire_vclass_cache

  safe_method :name => String

  class << self
    include Zena::Acts::Secure

    def roles_for_form
      if roles = secure(Role) { Role.all(:order => 'name ASC') }
        roles.map do |role|
          [role.name, role.id]
        end
      else
        []
      end
    end

    def indices_for_form
      [
        ['key/value',
          INDICES_FOR_FORM.map {|i| [i, i]}],
        ['field',
          FIELD_INDICES.map {|i| [i, ".#{i}"]}]
      ]
    end

    # Declare a new index table or field
    def add_field_index(*args)
      args.flatten.each do |idx|
        FIELD_INDICES << idx
      end
    end

    # Import a hash of virtual class definitions and try to build the virtual classes.
    def import(data)
      data.keys.map do |klass|
        build_column(klass, data)
      end
    end

    # Build a virtual class from a name and a hash of virtual class definitions. If
    # the superclass is in the data hash, it is built first.
    def build_column(klass, data)
      # TODO
      # return data[klass]['result'] if data[klass].has_key?('result')
      # if virtual_class = Node.get_class(klass)
      #   if virtual_class.superclass.to_s == data[klass]['superclass']
      #     virtual_class.import_result = 'same'
      #     return data[klass]['result'] = virtual_class
      #   else
      #     virtual_class.errors.add(:base, 'conflict')
      #     return data[klass]['result'] = virtual_class
      #   end
      # else
      #   superclass_name = data[klass]['superclass']
      #   if data[superclass_name]
      #     superclass = build_virtual_class(superclass_name, data)
      #     unless superclass.errors.empty?
      #       virtual_class = VirtualClass.new(:name => klass, :superclass => superclass_name, :create_group_id => current_site.public_group_id)
      #       virtual_class.errors.add(:base, 'conflict in superclass')
      #       return data[klass]['result'] = virtual_class
      #     end
      #   elsif superclass = Node.get_class(superclass_name)
      #     # ok
      #   else
      #     virtual_class = VirtualClass.new(:name => klass, :superclass => superclass_name, :create_group_id => current_site.public_group_id)
      #     virtual_class.errors.add(:base, 'missing superclass')
      #     return data[klass]['result'] = virtual_class
      #   end
      #
      #   # build
      #   create_group_id = superclass.kind_of?(VirtualClass) ? superclass.create_group_id : current_site.public_group_id
      #   virtual_class = create(data[klass].merge(:name => klass, :create_group_id => create_group_id))
      #   virtual_class.import_result = 'new'
      #   return data[klass]['result'] = virtual_class
      # end
    end

    def export
      # TODO
    end
  end

  def kpath
    @kpath ||= role.kpath
  end

  # Used to display index name in forms
  def index_name
    self.index.to_s.gsub(/\A\./,'')
  end

  def export
    {
      'ptype' => ptype,
      'index' => index,
    }
  end

  protected
    def set_defaults
      self[:site_id] = current_site.id
    end

    def name_not_in_models
      Node.native_classes.to_a.sort{|a,b| a[0] <=> b[0]}.each do |kpath, klass|
        name, set_name = self.name, "#{self.name}="
        if column = klass.schema.columns[self.name]
          # find column origin
          errors.add(:name, _('has already been taken in %s') % column.role.name)
          break
        elsif self.name =~ %r{_ids?$}
          errors.add(:name, _('invalid (cannot end with _id or _ids)'))
          break
        elsif klass.method_defined?(name)     || klass.protected_method_defined?(name)     || klass.private_method_defined?(name) ||
           klass.method_defined?(set_name) || klass.protected_method_defined?(set_name) || klass.private_method_defined?(set_name)
          errors.add(:name, _('invalid (method defined in %s)') % klass.to_s)
          break
        end
      end
    end

    def expire_vclass_cache
      VirtualClass.expire_cache!
    end
end
