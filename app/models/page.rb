=begin rdoc
== Index Page
+ZENA_ENV[:index_id]+ refers to a special project. This project is the root of all other pages or logs. It is used
to set default groups for new projects, to store 'global' events and pages.
=end
class Page < Node
  class << self
    def parent_class
      Page
    end
  
    def select_classes
      list = subclasses.inject([]) do |list, k|
        unless Document == k || k.ancestors.include?(Document)
          list << k.to_s
        end
        list
      end.sort
      list << 'Template'
      list.unshift 'Page'
    end
  end
  
  def klass
    self.class.to_s
  end
end