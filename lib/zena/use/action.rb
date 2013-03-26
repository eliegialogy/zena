module Zena
  module Use
    module Action
      module Common
        def win_id(node_zip, action)
          "#{current_site.host.gsub('.', '_')}_#{node_zip}_#{action}"
        end
        # This method renders an action link without using Rails actions so that we can feed it with
        # erb from Zafu.
        def node_action_link(action, node_zip, opts={})
          text  = opts[:text].blank? ? _("btn_#{action}") : opts[:text]
          title = opts[:title] || _("btn_title_#{action}")
          query = []
          if params = opts[:params]
            params.each do |k,v|
              query << "#{k}=#{v}"
            end
          end

          if %w{edit drive add_doc}.include?(action)
            case action
            when 'edit'
              url = "/nodes/#{node_zip}/versions/0/edit"
            when 'drive'
              url = "/nodes/#{node_zip}/edit"
            when 'add_doc'
              url = "/documents/new"
              query << "parent_id=#{node_zip}"
            end
            id  = win_id(node_zip, action)

            url = query.empty? ? url : "#{url}?#{query.join('&')}"
            tag = "<a href='#{url}' target='_blank' title='#{title}' onclick=\"Zena.open_window('#{url}', '#{id}', event);return false;\">"
          else
            query = query.empty? ? '' : "?#{query.join('&')}"
            tag  = "<a href='/nodes/#{node_zip}/versions/0/#{action}#{query}' onclick='Zena.m(this, \"put\");return false;' title ='#{title}'>"
          end
          "#{tag}#{text}</a>"
        end
      end

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common
        include RubyLess
        safe_method :login_path  => String
        safe_method :logout_path => String

        # These methods are used by swap to create the href
        safe_method [:next_in_list, String, String] => {:class => String, :method => 'next_in_list_s', :accept_nil => true}
        safe_method [:next_in_list, Number, String] => {:class => Number, :method => 'next_in_list_i', :accept_nil => true}

        def next_in_list_s(str, list)
          list = list.to_s.split(',').map(&:strip)
          str  = str.to_s
          list[((list.index(str) || -1) + 1) % list.size]
        end

        def next_in_list_i(nb, list)
          list = list.to_s.split(',').map(&:to_f)
          nb   = nb.to_f
          list[((list.index(nb) || -1) + 1) % list.size]
        end

        # Shows 'login' or 'logout' button.
        # Is this used ? Or do we just use the zafu tag alone ?
        # def login_link(opts={})
        #   if visitor.is_anon?
        #     link_to _('login'), login_path
        #   else
        #     link_to _('logout'), logout_url
        #   end
        # end

        # Node actions that appear on the web page
        def node_actions(node, opts={})
          actions = (opts[:actions] || 'all').to_s
          actions = 'edit,propose,refuse,publish,drive' if actions == 'all'

          return '' if node.new_record?
          res = actions.split(',').reject do |action|
            !node.can_apply?(action.to_sym)
          end.map do |action|
            node_action_link(action, node.zip, opts)
          end.join(" ")

          if res != ""
            "<span class='actions'>#{res}</span>"
          else
            ""
          end
        end

        # Actions that appear in the drive popup versions list
        def version_actions(version, opts={})
          return "" unless version.kind_of?(Version)
          # 'view' ?
          actions = (opts[:actions] || 'all').to_s
          actions = 'destroy_version,remove,redit,unpublish,propose,refuse,publish' if actions == 'all'

          node = version.node
          node.version = version

          actions.split(',').reject do |action|
            action.strip!
            if action == 'view'
              !node.can_apply?('publish')
            else
              !node.can_apply?(action.to_sym)
            end
          end.map do |action|
            version_action_link(action, version)
          end.join(' ')
        end

        # TODO: test
        def version_action_link(action, version)
          if action == 'view'
            # FIXME
            link_to_function(
            _("status_#{version.status}_img"),
            "Zena.version_preview('/nodes/#{version.node.zip}/versions/#{version.number}');", :title => _("status_#{version.status}"))
          else
            if action == 'destroy_version'
              action = 'destroy'
              method = :delete
            else
              method = :put
            end
            link_to_remote( _("btn_#{action}"), :url=>{:controller=>'versions', :action => action, :node_id => version.node[:zip], :id => version.number, :drive=>true}, :title=>_("btn_title_#{action}"), :method => method ) + "\n"
          end
        end


        # TODO: test
        def discussion_actions(discussion, opt={})
          opt = {:action=>:all}.merge(opt)
          return '' unless @node.can_drive?
          if opt[:action] == :view
            link_to_function(_('btn_view'), "opener.Zena.discussion_show(#{discussion[:id]}); return false;")
          elsif opt[:action] == :all
            if discussion.open?
              link_to_remote( _("img_open"), :url=>{:controller=>'discussions', :action => 'close' , :id => discussion[:id]}, :title=>_("btn_title_close_discussion")) + "\n"
            else
              link_to_remote( _("img_closed"), :url=>{:controller=>'discussions', :action => 'open', :id => discussion[:id]}, :title=>_("btn_title_open_discussion")) + "\n"
            end +
            if discussion.can_destroy?
              link_to_remote( _("btn_remove"), :url=>{:controller=>'discussions', :action => 'remove', :id => discussion[:id]}, :title=>_("btn_title_destroy_discussion")) + "\n"
            else
              ''
            end
          end
        end

        def login_path
          if params[:controller] == 'nodes'
            zen_path(@node, :prefix => AUTHENTICATED_PREFIX)
          else
            super
          end
        end

        def logout_path
          if params[:controller] == 'nodes' && @node.public?
            super :redirect => zen_path(@node, :prefix => visitor.lang)
          else
            super
          end
        end
      end # ViewMethods

      module ZafuMethods
        include Common

        def self.included(base)
          base.before_process :filter_actions
        end

        def r_debug
          %Q{
<pre style='background:white; color:black; border:1px solid red; display:table;'>
class #{node.klass}: #{Array(node.klass).first.columns.keys.join(', ')}
</pre>
          }
        end

        alias r_d r_debug

        def r_login_link
          if dynamic_blocks?
            @markup.tag ||= 'a'
            markup = @markup.tag == 'a' ? @markup : Zafu::Markup.new('a')

            else_markup = markup.dup
            else_markup.set_dyn_param('href', '<%= logout_path %>')

            markup.set_dyn_param('href', '<%= login_path %>')
            unless markup.param[:rel]
              markup.set_param('rel', 'nofollow')
            end

            out markup.wrap(expand_if("visitor.is_anon?", self.node, else_markup))
          else
            out "<% if visitor.is_anon? %>"
            out "<%= link_to #{_('login').inspect}, login_path, :rel => 'nofollow' %>"
            out "<% else %>"
            out "<%= link_to #{_('logout').inspect}, logout_path %>"
            out "<% end %>"
          end
        end

        def r_visitor_link
          out "<% if !visitor.is_anon? %>"
          if dynamic_blocks?
            @markup.tag ||= 'a'
            link = '<%= user_path(visitor) %>'
            if @markup.tag == 'a'
              @markup.set_dyn_param(:href, link)
              out wrap(expand_with)
            else
              markup = Zafu::Markup.new('a')
              markup.set_dyn_param(:href, link)
              out wrap(markup.wrap(expand_with))
            end
          else
            out wrap("<%= link_to visitor.node.title, user_path(visitor) %>")
          end
          out "<% end %>"
        end

        def r_action
          return parser_error("Missing 'select' parameter.") unless action = @params[:select]

          if self.node.will_be? Node
            node = self.node
          elsif self.node.will_be? Version
            node = "#{self.node}.node"
          else
            return parser_error("Invalid option 'actions' for #{node.klass}.")
          end

          params = {}
          @params.each do |k,v|
            next if k == :select
            params[k] = RubyLess.translate_string(self, v)
          end
          out node_action_link(action, "<%= #{node}.zip %>", :text => text_for_link(''), :params => params)
        end

        def filter_actions
          if actions = @params.delete(:actions)
            node = self.node
            if node.will_be? Node
            elsif node.will_be? Version
              node = "#{node}.node"
            else
              out parser_error("Invalid option 'actions' for #{node.klass}.")
              return
            end

            if publish = @params.delete(:publish)
              out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}, :publish => #{publish.inspect}) %>"
            else
              out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}) %>"
            end
          end
        end


        # TODO: test
        def r_swap
          if upd = @params.delete(:update)
            if upd == '_page'
              block = '_page'
            elsif block = find_target(upd)
              # ok
              if ancestor('block') || ancestor('each')
                # FIXME: not used
                upd_both = '&upd_both=true'
              else
                upd_both = ''
              end
            else
              return
            end
          elsif block = (ancestor('block') || ancestor('each'))
            # ancestor: ok
          elsif parent && block = parent.descendant('block')
            # sibling: ok
            upd_both = ''
          else
            return parser_error("missing 'block' in same parent")
          end

          return parser_error("missing 'states' parameter") unless @params[:states]

          # This will be RubyLess evaluated
          query_params = @params.merge("node[#{@params[:attr]}]" => "next_in_list(this.#{@params[:attr]}, %Q{#{@params[:states]}})")
          query_params.delete(:states)
          query_params.delete(:attr)
          out make_link(:update => block, :action => 'update', :query_params => query_params, :method => :put)
        end
      end # ZafuMethods

    end # Action
  end # Use
end # Zena