require 'test_helper'

class SiteTest < Zena::Unit::TestCase

  context 'on site creation' do
    setup do
      Thread.current[:visitor] = nil
    end

    subject do
      Site.create_for_host('super.host', 'secret')
    end

    should 'create valid site' do
      # should populate site
      assert_difference('Node.count', 18) do
        subject
      end

      # should create anon user
      assert_nil subject.anon.login

      assert_equal 'Anonymous User', subject.anon.node.title

      # should create an admin user
      assert_equal 1, subject.admin_user_ids.size

      admin = secure(User) { User.find(:first, :conditions => "status >= #{User::Status[:admin]}") }

      assert_equal 'Admin User', admin.node.title

      # should return a new project as root node
      assert_kind_of Project, subject.root_node

      # should install base skin
      index_zafu = secure(Node) { subject.root_node.find(:first, "template where title like 'Node%login' in site") }
      assert_kind_of Template, index_zafu
      assert_equal '+login', index_zafu.mode
    end
  end

  def test_create_site_with_opts
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'fr') }
    site = Site.find(site[:id]) # reload
    assert_equal ['fr'], site.lang_list
    assert_equal 'fr', site.default_lang
    assert_equal 'fr', site.anon.lang
  end

  def test_create_site_with_opts
    with_caching do
      site = nil
      assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'fr') }
      site = Site.find(site[:id]) # reload
      assert_equal ['fr'], site.lang_list
      assert_equal 'fr', site.default_lang
      assert_equal 'fr', site.anon.lang
      assert_equal 7200, site[:redit_time] # default 2h
    end
  end

  def test_create_site_with_opts_bad_lang
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'en_US') }
    site = Site.find(site[:id]) # reload
    assert_equal ['en'], site.lang_list
    assert_equal 'en', site.default_lang
    assert_equal 'en', site.anon.lang
  end

  def test_create_site_bad_name
    site = Site.create_for_host('../evil.com', 'zoomzoom')
    assert site.new_record?
    assert site.errors[:host]
  end

  def test_valid_site
    login(:lion)
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "french, en")
    assert_equal 'invalid', site.errors[:languages]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'')
    assert_equal 'invalid', site.errors[:default_lang]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'french')
    assert_equal 'invalid', site.errors[:default_lang]
    site = sites(:zena)
    assert site.update_attributes(:languages => "fr ,en, ru ", :default_lang=>'ru')
  end

  def test_public_path
    site = sites(:zena)
    assert_equal "/test.host/public", site.public_path
    site = sites(:ocean)
    assert_equal "/ocean.host/public", site.public_path
  end

  def test_data_path
    site = sites(:zena)
    assert_equal "/test.host/data", site.data_path
    site = sites(:ocean)
    assert_equal "/ocean.host/data", site.data_path
  end

  def test_zafu_path
    site = sites(:zena)
    assert_equal "/test.host/zafu", site.zafu_path
    site = sites(:ocean)
    assert_equal "/ocean.host/zafu", site.zafu_path
  end

  def test_anonymous
    site = sites(:zena)
    anon = site.anon
    assert_kind_of User, anon
    assert anon.is_anon?
    assert_equal 'Mr nobody', anon.node.title
    assert_equal users_id(:anon), anon[:id]
    anon.site = site
    assert anon.is_anon?

    login(:incognito)
    site = sites(:ocean)
    anon = site.anon
    assert_equal 'Miss incognito', anon.node.title
    assert_equal users_id(:incognito), anon[:id]
    anon.site = site
    assert anon.is_anon?
  end
  
  context 'A site' do
    subject do
      sites(:zena)
    end

    should 'respond to any_admin' do
      assert_kind_of User, subject.any_admin
      assert_equal users(:lion), subject.any_admin
    end
  end # A site
  

  def test_public_group
    login(:anon)
    site = sites(:zena)
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:public), grp[:id]

    login(:incognito)
    site = sites(:ocean)
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:public), grp[:id]
  end

  def test_site_group
    login(:anon)
    site = sites(:zena)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:workers), grp[:id]

    login(:incognito)
    site = sites(:ocean)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:aqua), grp[:id]
  end

  def test_protected_fields
    site = sites(:zena)
    site.update_attributes(:id=>sites_id(:ocean), :root_id=>11, :host=>'example.com')
    site = sites(:zena) # reload
    assert_equal sites_id(:zena), site[:id]
    assert_equal nodes_id(:zena), site[:root_id]
    assert_equal 'test.host', site[:host]
  end

  def test_lang_list
    site = sites(:zena)
    site.languages = "en,fr"
    assert_equal ['en', 'fr'], site.lang_list
    site.languages = "en,fr, ru , es"
    assert_equal ['en', 'fr', 'ru', 'es'], site.lang_list
  end

  def test_redit_time
    site = sites(:ocean)
    assert_equal '2 hours', site.redit_time
    site.redit_time = '0'
    assert_equal '0', site.redit_time
    assert site.save
    site = sites(:ocean)
    assert_equal '0', site.redit_time
    assert site.update_attributes(:redit_time => '5h 1d 34 seconds')
    assert_equal '1 day 5 hours 34 seconds', site.redit_time
  end

  def test_site_attributes
    login(:lion)
    site = sites(:zena)
    assert site.update_attributes(:recaptcha_pub => "something", :recaptcha_priv => "anything else")
    site = sites(:zena)
    assert_equal "something", site.prop['recaptcha_pub']
    assert_equal "something", site.prop['recaptcha_pub']
    assert_equal "anything else", site.prop['recaptcha_priv']
    assert_equal "anything else", site.prop['recaptcha_priv']
  end

  def test_attributes_for_form
    assert Site.attributes_for_form[:bool].include?('authentication')
    assert Site.attributes_for_form[:text].include?('default_lang')
  end

  def test_find_by_host
    site1 = Site.find_by_host('test.host')
    site2 = Site.find_by_host('test.host.')
    assert_equal site1, site2
    assert_equal "/test.host/public", site2.public_path
    assert_equal "/test.host/public", site1.public_path
  end

  def test_rebuild_vhash
    login(:tiger)
    Node.connection.execute "UPDATE nodes SET vhash = NULL WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:opening)})"
    visitor.site.rebuild_vhash
    status  = secure(Node) { nodes(:status)  }
    opening = secure(Node) { nodes(:opening) }
    assert_equal Hash['w'=>{'fr' => versions_id(:status_fr),      'en' => versions_id(:status_en)},
                      'r'=>{'fr' => versions_id(:status_fr),      'en' => versions_id(:status_en)}], status.vhash

    assert_equal Hash['w'=>{'fr' => versions_id(:opening_red_fr), 'en' => versions_id(:opening_en)},
                      'r'=>{'fr' => versions_id(:opening_fr),     'en' => versions_id(:opening_en)}], opening.vhash
  end

  def test_rebuild_fullpath
    login(:tiger)
    Node.connection.execute "UPDATE nodes SET fullpath = NULL"
    visitor.site.rebuild_fullpath
    status  = secure(Node) { nodes(:status)  }
    opening = secure(Node) { nodes(:opening) }
    cleanWater = secure(Node) { nodes(:cleanWater) }
    art = secure(Node) { nodes(:art) }
    assert_equal fullpath(:projects, :cleanWater, :status), status.fullpath
    assert_equal fullpath(:projects, :cleanWater), status.basepath
    assert_equal false, status.custom_base

    assert_equal fullpath(:projects, :cleanWater, :opening), opening.fullpath
    assert_equal fullpath(:projects, :cleanWater), opening.basepath
    assert_equal false, opening.custom_base

    assert_equal fullpath(:projects, :cleanWater), cleanWater.fullpath
    assert_equal fullpath(:projects, :cleanWater), cleanWater.basepath
    assert_equal true, cleanWater.custom_base

    assert_equal fullpath(:collections, :art), art.fullpath
    assert_equal '', art.basepath
    assert_equal false, art.custom_base
  end

  context 'Clearing a site cache' do
    setup do
      login(:tiger)
    end

    subject do
      visitor.site
    end

    should 'not alter fullpath' do
      node = secure!(Node) { nodes(:status) }
      assert_equal fullpath(:projects, :cleanWater, :status), node.fullpath
      subject.clear_cache
      node = secure!(Node) { nodes(:status) }
      assert_equal fullpath(:projects, :cleanWater, :status), node.fullpath
    end
  end

  context 'Rebuilding site index' do
    setup do
      login(:tiger)
      Node.connection.tables.each do |name|
        if name =~ /^idx_/
          Node.connection.execute "DELETE FROM #{name}"
        end
      end
      flds = Zena::Use::Fulltext::FULLTEXT_FIELDS.map { |fld| "#{fld} = ''"}.join(',')
      Version.connection.execute("UPDATE versions SET #{flds}")
    end

    subject do
      visitor.site
    end

    should 'rebuild visible entries for all objects' do
      assert_difference('IdxNodesMlString.count',
        # title index on all nodes
        subject.lang_list.count * Node.count(:conditions => {:site_id => subject.id}) +
        # search index on Letter nodes
        subject.lang_list.count * Node.count(:conditions => ['site_id = ? AND kpath like ?', subject.id, 'NNL%'])
        ) do
        subject.rebuild_index
      end
    end

    should 'build index entries for each lang' do
      subject.rebuild_index
      ml_indices = Hash[*IdxNodesMlString.find(:all, :conditions => {:node_id => nodes_id(:status), :key => 'title'}).map {|r| [r.lang, r.value]}.flatten]
      assert_equal Hash[
        'de'=>'status title',
        'fr'=>'Etat des travaux',
        'es'=>'status title',
        'en'=>'status title'], ml_indices
    end
  end


  private
    def fullpath(*args)
      args.map {|sym| nodes_zip(sym).to_s}.join('/')
    end
end
