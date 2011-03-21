require 'test_helper'

class NestedAttributesAliasViewTest < Zena::View::TestCase
  include Zena::Use::NestedAttributesAlias::ViewMethods

  class HashAsMethods < Hash
    def initialize(hash = {})
      replace(hash)
    end

    def method_missing(method, *args)
      if method.to_s =~ /^(.*)=$/
        self[$1] = args.first
      else
        self[method.to_s]
      end
    end
  end

  class Foo < ActiveRecord::Base
    set_table_name 'nodes'
    include Zena::Use::NestedAttributesAlias::ModelMethods

    nested_attributes_alias %r{^v_(.+)}      => 'version'
    nested_attributes_alias %r{^c_(.+)}      => 'version.content'
    nested_attributes_alias %r{^d_(.+)$}     => 'version.dyn'
    nested_attributes_alias %r{^(.+)_(id|status|comment)$} => Proc.new {|obj, m| obj.relation_alias(m) }

    def relation_alias(match)
      if ['friend', 'dog'].include?(match[1])
        if match[2] == 'id'
          ['link', match[1], 'other_id']
        else
          ['link', match[1], match[2]]
        end
      else
        nil
      end
    end

    def link
      @link ||= HashAsMethods.new.tap do |l|
        l.friend = HashAsMethods.new('other_id' => 1234)
      end
    end

    def version
      @version ||= HashAsMethods.new('title' => 'version title').tap do |v|
        v.content = HashAsMethods.new('width' => 33)
      end
    end

  end

  def setup
    @foo = Foo.new
  end

  def test_text_field_should_find_value
    assert_match 'input#foo_v_title[@name="foo[v_title]"][@value="version title"][@type="text"]', text_field('foo', 'v_title')
  end

  def test_text_field_should_find_value_through_proc
    assert_match 'input#foo_friend_id[@name="foo[friend_id]"][@value="1234"]', text_field('foo', 'friend_id')
  end

  def test_text_field_should_find_value_deeply_nested
    assert_match 'input#foo_c_width[@name="foo[c_width]"][@value="33"]', text_field('foo', 'c_width')
  end

  def test_password_field_should_find_value
    @foo.version.dyn = HashAsMethods.new('secret' => 'yellow')
    assert_match 'input#foo_d_secret[@name="foo[d_secret]"][@value="yellow"][@type="password"]', password_field('foo', 'd_secret')
  end

  def test_hidden_field_should_find_value
    assert_match 'input#foo_v_title[@name="foo[v_title]"][@value="version title"][@type="hidden"]', hidden_field('foo', 'v_title')
  end

  def test_file_field_should_find_value
    assert_match 'input#foo_v_title[@name="foo[v_title]"][@type="file"]', file_field('foo', 'v_title')
  end

  def test_text_area_should_find_value
    assert_match 'textarea#foo_v_title[@name="foo[v_title]"]', tag = text_area('foo', 'v_title')
    assert_match %r{version title}, tag
  end

  def test_check_box_should_find_value
    tag = check_box('foo', 'v_title', {}, 'version title', '')
    assert_match 'input[@name="foo[v_title]"][@value=""][@type="hidden"]', tag
    assert_match 'input#foo_v_title[@name="foo[v_title]"][@value="version title"][@type="checkbox"][@checked="checked"]', tag
  end

  def test_radio_button_should_find_value
    tag = radio_button('foo', 'v_title', 'version title')
    assert_match 'input[@name="foo[v_title]"][@value="version title"][@type="radio"][@checked="checked"]', tag
  end
end
