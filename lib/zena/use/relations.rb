module Zena
  module Use
    module Relations

      # The ProxyLoader is used so that nested_attributes_alias resolution through node.send('link').send('friend')
      # makes it to the 'friend' relation proxy.
      class ProxyLoader
        include RubyLess
        safe_method [:[], String] => {:class => 'RelationProxy', :nil => true}

        DUMMY = Class.new do
          def other_id;   nil; end
          def other_ids;  [];  end
          def other_zips; [];  end
          def to_s; 'nil'; end
        end.new.freeze

        def initialize(node)
          @node = node
        end

        def [](role)
          @node.relation_proxy(role.to_s) || DUMMY
        end

        def send(role)
          @node.relation_proxy(role.to_s)
        end

        def method_missing(sym, *args)
          nil
        end
      end

      LINK_ATTRIBUTES = [:status, :comment, :date]
      LINK_REGEXP = /^([\w_]+)_(ids?|zips?|#{LINK_ATTRIBUTES.join('|')})$/

      module ClassMethods

        # All relations related to the current class/virtual_class with its ancestors.
        def all_relations(start=nil, group_filter=nil)
          if group_filter
            group_filter = "#{group_filter}%"
            rel_as_source = RelationProxy.find(:all,
              :conditions => ["site_id = ? AND source_kpath IN (?) AND rel_group LIKE ?", current_site[:id], split_kpath, group_filter])
            rel_as_target = RelationProxy.find(:all,
              :conditions => ["site_id = ? AND target_kpath IN (?) AND rel_group LIKE ?", current_site[:id], split_kpath, group_filter])
          else
            rel_as_source = RelationProxy.find(:all,
              :conditions => ["site_id = ? AND source_kpath IN (?)", current_site[:id], split_kpath])
            rel_as_target = RelationProxy.find(:all,
              :conditions => ["site_id = ? AND target_kpath IN (?)", current_site[:id], split_kpath])
          end
          rel_as_source.each {|rel| rel.source = start }
          rel_as_target.each {|rel| rel.target = start }
          (rel_as_source + rel_as_target).sort {|a,b| a.other_role <=> b.other_role}
        end

        # Class path hierarchy. Example for (Post) : N, NN, NNP
        def split_kpath
          @split_kpath ||= begin
            klasses   = []
            kpath.split(//).each_index { |i| klasses << kpath[0..i] }
            klasses
          end
        end
      end

      module ModelMethods
        def self.included(base)
          base.extend Zena::Use::Relations::ClassMethods
          base.validate      :relations_valid
          base.after_save    :update_relations
          base.after_destroy :destroy_links
          base.safe_method   :rel => ProxyLoader

          base.safe_method :l_status  => {:class => Number, :nil => true}
          base.safe_method :l_comment => {:class => String, :nil => true}
          base.safe_method :l_date    => {:class => Time,   :nil => true}
          base.safe_method :link_id   => {:class => Number, :nil => true}

          base.nested_attributes_alias LINK_REGEXP => Proc.new {|obj, m| obj.relation_alias(m) }
          base.class_eval <<-END
            attr_accessor :link
            class << self
              include Zena::Use::Relations::ClassMethods
            end

            def relation_base_class
              #{base}
            end

            HAS_RELATIONS = true
          END
        end


        # Return an array of accessor methods for the matched relation alias.
        def relation_alias(match)
          return nil if match[0] == 'parent_id'
          role     = match[1]
          field    = match[2]

          if relation = relation_proxy(role)
            # We use 'links' so that we can keep the old @link accessor.
            # FIXME: rename 'link' when we refactor the @link part.
            if field =~ /^ids?|zips?/
              ['rel', role, "other_#{field}"]
            else
              ['rel', role, field]
            end
          else
            nil
          end
        end

        # Linked_node is a way to store a linked node during calendar display or ajax return
        # calls so the template knows which "couple" has just been formed or removed.
        # The linked_node "node" must respond to "l_date".
        def linked_node=(node)
          @linked_node = node
        end

        def linked_node
          @linked_node ||= @relation_proxies ? @relation_proxies[@relation_proxies.keys.first].last_target : nil
        end

        # status defined through loading link
        def l_status
          return @l_status if defined? @l_status
          val = @link ? @link[:status] : self['l_status']
          val ? val.to_i : nil
        end

        # TODO: could we use LINK_ATTRIBUTES and 'define_method' here ?

        # comment defined through loading link
        def l_comment
          return @l_comment if defined? @l_comment
          @link ? @link[:comment] : self['l_comment']
        end

        # date defined through loading link
        def l_date
          return @l_date if defined? @l_date
          @l_date = @link ? @link[:date] : (self['l_date'] ? Time.parse(self['l_date']) : nil)
        end

        def link_id
          @link ? @link[:id] : (self[:link_id] == -1 ? nil : self[:link_id]) # -1 == dummy link
        end

        def link_id=(v)
          if @link && @link[:id].to_i != v.to_i
            @link = nil
          end
          self[:link_id] = v.to_i
          if @link_attributes_to_update
            if rel = relation_proxy_from_link
              @link_attributes_to_update.each do |k,v|
                rel.send("other_#{k}=",v)
              end
            end
          end
        end

        # FIXME: this method does an 'update' not only 'add'
        def add_link(role, hash)
          if rel = relation_proxy(role)
            rel.qb         = hash[:qb]         if hash.has_key?(:qb)
            rel.other_id   = hash[:other_id]   if hash.has_key?(:other_id)
            rel.other_ids  = hash[:other_ids]  if hash.has_key?(:other_ids)
            rel.other_zip  = hash[:other_zip]  if hash.has_key?(:other_zip)
            rel.other_zips = hash[:other_zips] if hash.has_key?(:other_zips)
            LINK_ATTRIBUTES.each do |k|
              rel.send("other_#{k}=", hash[k]) if hash.has_key?(k)
            end
          else
            errors.add(role, 'invalid relation')
          end
        end

        def remove_link(link)
          if link[:source_id] != self[:id] && link[:target_id] != self[:id]
            errors.add('link', "not related to this node")
            return false
          end
          # find proxy
          if rel = relation_proxy_from_link(link)
            rel.remove_link(link)
          else
            errors.add('link', "cannot remove (relation proxy not found).")
          end
        end

        def rel_attributes=(hash)
          return unless hash.kind_of?(Hash)
          hash.each do |role, definition|
            if role =~ /\A\d+\Z/
              # key used as array
            elsif role =~ /^(.+)_attributes$/
              # key used as role
              definition['role'] ||= $1
            elsif definition.kind_of?(Hash)
              # key used as role, without the '_attributes'
              definition['role'] ||= role
            else
              # qb
              definition = {'role' => role, 'qb' => definition}
            end
            # TODO: only use string keys
            add_link(definition.delete('role'), definition.symbolize_keys)
          end
        end

        def rel
          ProxyLoader.new(self)
        end

        # This accessor is used when the data arrives with the syntax
        # rel => { friend => {...} }
        def rel=(hash)
          self.rel_attributes = hash
        end

        def l_comment=(v)
          @l_comment = v.blank? ? nil : v
          if rel = relation_proxy_from_link
            rel.other_comment = @l_comment
          end
        end

        def l_status=(v)
          @l_status = v.blank? ? nil : v.to_i
          if rel = relation_proxy_from_link
            rel.other_status = @l_status
          end
        end

        def l_date=(v)
          @l_date = v.blank? ? nil : v
          if rel = relation_proxy_from_link
            rel.other_date = @l_date
          end
        end

        def all_relations
          @all_relations ||= self.vclass.all_relations(self)
        end

        def relations_for_form
          all_relations.map {|r| [r.other_role.singularize, r.other_role]}
        end

        # List the links, grouped by role
        def relation_links
          res = []
          all_relations.each do |rel|
            #if relation.record_count > 5
            #  # FIXME: show message ?
            #end
            links = rel.records(:limit => 5, :order => "link_id DESC")
            res << [rel, links] if links
          end
          res
        end

        # Find relation proxy for the given role.
        def relation_proxy(role)
          @relation_proxies ||= {}
          return @relation_proxies[role] if @relation_proxies.has_key?(role)
          @relation_proxies[role] = RelationProxy.get_proxy(self, role.singularize.underscore)
        end

        def relation_proxy_from_link(link = nil)
          unless link
            if @link
              link = @link
            elsif self.link_id
              link = @link = Link.find_through(self, self.link_id)
            end
            return nil unless link
          end
          @relation_proxies ||= {}
          return @relation_proxies[link.role] if @relation_proxies.has_key?(link.role)
          @relation_proxies[link.role] = link.relation_proxy(self)
        end

        private

          # Used to create / destroy / update links through pseudo methods 'icon_id=', 'icon_status=', ...
          # Pseudo methods created for a many-to-one relation (icon_for --- icon):
          # icon_id=::      set icon
          # icon_status=::  set status field for link to icon
          # icon_comment=:: set comment field for link to icon
          # icon_for_ids=:: set all nodes for which the image is an icon (replaces old values)
          # icon_for_id=::  add a node for which the image is an icon (adds a new value)
          # icon_id::       get icon id
          # icon_zip::      get icon zip
          # icon_status::   get status field for link to icon
          # icon_comment::  get comment field for link to icon
          # icon_for_ids::  get all node ids for which the image is an icon
          # icon_for_zips:: get all node zips for which the image is an icon
          def method_missing(meth, *args, &block)
            # first try rails' version of method missing
            super(meth, *args, &block)
          rescue NoMethodError => err
            # 1. is this a method related to a relation ?
            if meth.to_s =~ LINK_REGEXP
              role  = $1
              field = $2
              mode  = $3
              # 2. is this a valid role ?
              if rel = relation_proxy(role)
                if mode == '='
                  # set
                  rel.send("other_#{field}=", args[0])
                else
                  # get
                  if field != 'ids' && field != 'zips' && !rel.unique?
                    # ask for a single value in a ..-to-many relation
                    # 1. try to use focus
                    if @link
                      rel.other_link = @link
                    elsif self.link_id
                      @link = Link.find_through(self, self.link_id)
                      rel.other_link = @link
                    else
                      return nil
                    end
                  end
                  rel.send("other_#{field}")
                end
              else
                # invalid relation
                if mode == '='
                  errors.add(role, "invalid relation") unless args[0].blank?
                  return args[0]
                else
                  # ignore
                  return nil
                end
              end
            else
              # not related to relations
              raise err
            end
          end

          # Make sure all updated relation proxies are valid
          def relations_valid
            return true unless @relation_proxies
            @relation_proxies.each do |role, rel|
              next unless rel
              unless rel.attributes_to_update_valid?
                errors.add(role, rel.link_errors.map {|k,v| "#{k} => #{v}"}.join(', '))
              end
            end
          end

          # Update/create links defined in relation proxies
          def update_relations
            return unless @relation_proxies
            @relation_proxies.each do |role, rel|
              next unless rel
              rel.update_links!
            end
          end

          # Destroy all links related to this node
          def destroy_links
            Link.find(:all, :conditions => ["source_id = ? OR target_id = ?", self[:id], self[:id]]).each do |l|
              l.destroy
            end
          end
      end # ModelMethods
    end # Relations
  end # Use
end # Zena