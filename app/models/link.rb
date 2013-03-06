class Link < ActiveRecord::Base
  include Zena::Use::QueryLink::ModelMethods
  
  include RubyLess
  safe_attribute :status, :comment, :date
  # Used in tag cloud
  safe_method :name  => String
  safe_method :link_count => Number

  attr_reader :relation
  attr_accessor :start, :side

  class << self
    def find_through(node, link_id)
      return nil unless link = Link.find(:first, :conditions => ['(source_id = ? OR target_id = ?) AND id = ?', node[:id], node[:id], link_id])
      link.start = node
      node.link  = link
      link
    end
  end

  # TODO: is this used ?
  def update_attributes_with_transformations(attrs)
    return false unless @node

    if attrs['role']
      # TODO: destroy this link and create a new one ?
    end

    rel = @node.relation_proxy_from_link(self)
    rel.other_link = self

    Zena::Use::Relations::LINK_ATTRIBUTES.each do |k|
      k = k.to_s # TODO: use only strings or symbols but avoid this mess
      rel.send("other_#{k}=", attrs[k]) if attrs.has_key?(k)
      self[k] = attrs[k]
    end

    if other_id = attrs['other_id'] || attrs['other_zip']
      other_id = secure(Node) { Node.translate_pseudo_id(other_id, :id, @node) }
      rel.other_id = other_id
      if @side == :source
        self[:target_id] = other_id
        @target = nil
      else
        self[:source_id] = other_id
        @source = nil
      end
    end

    @node.save
    @node.link = self
    @errors = @node.errors
    return errors.empty?
  end

  def target
    @target ||= begin
      node = secure!(Node) { Node.find(target_id) }
      node.link = self
      node
    end
  end

  def source
    @source ||= begin
      node = secure!(Node) { Node.find(source_id) }
      node.link = self
      node
    end
  end

  def start=(node)
    @node = node
    if @node[:id] == self[:source_id]
      @side = :source
      @source = @node
    else
      @side = :target
      @target = @node
    end
  end

  def other
    @side == :source ? target : source
  end

  def this
    @side == :source ? source : target
  end

  def other_zip
    other[:zip]
  end

  def this_zip
    this[:zip]
  end

  def zip
    self[:id]
  end

  def can_write?
    this.can_write?
  end

  def relation_proxy(node=nil)
    return @relation_proxy if defined?(@relation_proxy)
    rel = RelationProxy.find(self[:relation_id])
    @node = node if node
    if @node
      if self[:source_id] == @node[:id]
        rel.side = :source
      else
        rel.side = :target
      end
      rel.start = @node
    end
    @relation_proxy = rel
  end

  def role
    relation_proxy.other_role
  end
  
  # Used by tags
  def name
    comment
  end
  
  def link_count
    read_attribute('link_count') || 0
  end
end
