# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + "/../../../test_helper.rb"

class UbiquoFormBuilderTest < ActionView::TestCase

  attr_accessor :params

  def setup
    self.params = { :controller => 'tests', :action => 'index' }
  end

  test "form" do
    # Testing the tester.
    the_form do |ufb|
      assert_equal Ubiquo::Helpers::UbiquoFormBuilder, ufb.class
      concat("mytext")
    end
    assert_select "form" do |list|
      assert_equal "/ubiquo/users", list.first.attributes["action"]
    end
    assert_select "form", "mytext"
  end

  test "form field" do
    assert_nothing_thrown {
      the_form do |form|
        form.text_field :lastname
        form.hidden_field :lastname
      end
    }
  end

  test "form field text_field" do
    the_form do |form|
      form.text_field :lastname
      form.text_field :lastname, :class=> "alter"
    end
    assert_select "form" do |list|
      assert_equal "/ubiquo/users", list.first.attributes["action"]
      assert_select "div.form-item" do
        assert_select "label", "Lastname"
        assert_select "input[type='text'][name='user[lastname]'][value='Bar']"
        assert_select "input[type='text'][name='user[lastname]'][value='Bar'][class='alter']"
      end
    end
  end

  test "group" do
    the_form do |f|
      f.group {}
    end
    assert_select "form div.form-item"
  end

  test "submit group" do
    the_form do |f|
      f.submit_group {}
    end
    assert_select "form div.form-item-submit"
  end

  test "Submit group for new and edit" do
    self.expects(:t).with("ubiquo.create").returns("ubiquo.create-value")
    self.expects(:t).with("ubiquo.save").returns("ubiquo.save-value")
    self.expects(:t).with("ubiquo.back_to_list").returns("ubiquo.back_to_list-value")

    the_form do |f|
      f.submit_group do
        f.create_button
        f.back_button
        f.update_button
      end
    end

    assert_select "form div.form-item-submit" do |blocks|
      assert_equal 1, blocks.size
      block = blocks.first
      assert_select block, "input[type='submit'][value='ubiquo.create-value']"
      assert_select block, "input[type='submit'][value='ubiquo.save-value']"
      assert_select block, "input[type='button']" do |buttons|
        assert buttons.first.attributes["onclick"].include?( "href=" )
      end
    end
  end

  test "Custom params for submit buttons" do
    self.expects(:t).with("ubiquo.create-custom").returns("ubiquo.create-custom-value")
    self.expects(:t).with("ubiquo.save-custom").returns("ubiquo.save-custom-value")

    the_form do |f|
      f.submit_group(:class => "alter-submit") do
        # Custom params
        f.create_button( "c-custom", :class => "bt-create2" )
        f.create_button( nil, :i18n_label_key => "ubiquo.create-custom")
        f.back_button( "back-custom", {:js_function => "alert('foo');", :class => "bt-back2"} )
        f.update_button( "u-custom", :class => "bt-update2" )
        f.update_button( nil, :i18n_label_key => "ubiquo.save-custom")
      end
    end

    assert_select "form div.alter-submit", 1 do |blocks|
      block = blocks.first
      assert_select block, "input[type='submit'][value='c-custom'][class='bt-create2']"
      assert_select block, "input[type='submit'][value='ubiquo.create-custom-value']"
      assert_select block, "input[type='button'][value='back-custom'][class='bt-back2']" do |buttons|
        assert buttons.first.attributes["onclick"].include?( "alert('foo');" )
      end
      assert_select block, "input[type='submit'][value='u-custom'][class='bt-update2']"
      assert_select block, "input[type='submit'][value='ubiquo.save-custom-value']"
    end
  end

  test "custom_block" do
    the_form do |form|
      form.custom_block do
        '<div class="custom-form-item">'.html_safe +
        form.label(:lastname, "imalabel") +
        form.text_field(:lastname) +
        "</div>".html_safe
     end
    end

    assert_select "form > div.form-item", 0
    # Only a label (means that text_field has not generated any label)
    assert_select "form label", "imalabel"

    assert_select "form input[type='text'][value='Bar']", 1
  end

  test "disable group on selectors" do
    self.expects(:relation_selector).returns("rel")
    assert_nothing_raised{
      the_form do |form|
        form.group :label => "custom_label_group", :type => :fieldset do
          form.relation_selector :actors, :type => :checkbox
        end
      end
    }
  end
  test "show description, help info and translatable hints" do
    self.expects(:t).with("ubiquo.translatable_field").returns("ubiquo.translatable_field")

    a = the_form do |form|
      form.group(:class => "a0") do
        form.text_field :lastname, :translatable => true
      end
      form.group(:class => "a1") do
       form.text_field :lastname, :class=> "alter", :translatable => "foo"
      end
      form.group(:class => "a2") do
        form.text_field :lastname, :class=> "alter2", :description => "foo2", :help => "Info text"
      end
      form.group(:class => "a3") do
        form.text_field :lastname, :class=> "alter3", :translatable => "foo3", :description => "bar"
      end

    end

    assert_select "form" do |list|
      assert_equal "/ubiquo/users", list.first.attributes["action"]
      assert_select ".a0" do
        assert_select "p.translation-info", "ubiquo.translatable_field"
        assert_select "p.description",0
      end
      assert_select ".a1" do
        assert_select "p.translation-info", "foo"
        assert_select "p.description",0
      end
      assert_select ".a2" do
        assert_select "p.translation-info",0
        assert_select "p.description", "foo2"
        assert_select "div.form-help" do
          assert_select "a.btn-help" do |link|
            assert_equal link.first.attributes["onclick"],
              "this.getOffsetParent().toggleClassName('active'); return false;",
              "Should have a js method to assign 'active' class to parent <div>"
            assert_equal link.first.attributes["tabindex"], "100",
              "Should have a big 'tabindex' attribute to jump <a> " +
              "tag when navigating with TAB key within the form."
          end
          assert_select "div.content" do
            assert_select "p", "Info text"
          end
        end
      end
      assert_select ".a3" do
        assert_select "p.translation-info","foo3"
        assert_select "p.description", "bar"
      end
    end
  end

  test "show checkox correctly" do
    the_form do |form|
       form.group(:class => "a0") do
       form.check_box :is_admin
      end

      form.group(:class => "a1") do
        form.check_box :is_admin, :translatable => true
      end
    end

    assert_select "form" do |list|
      assert_select ".a0" do
        assert_select ".form-item" do
          assert_equal ["label", "input","input"], css_select(".form-item *").map(&:name)

          assert_select "input[label_on_bottom='false']", 0
        end
      end

      assert_select ".a1" do
        assert_select ".form-item" do
          assert_equal ["label", "input","input","p"], css_select(".form-item *").map(&:name)
          assert_select "input[label_on_bottom='false']", 0
        end
      end
    end

  end

  test "tabbed blocks" do
    self.expects(:t).with("personal_data").returns("personal_data").at_least_once
    self.expects(:t).with("rights").returns("rights").at_least_once

    the_form do |form|
       form.group(:type => :tabbed, :class=> "a-group-of-tabs") do |group|
         group.add(t("personal_data")) do
           form.text_field :lastname
         end
         group.add(t("rights"), :class => "custom-tab-class") do
           form.check_box :is_admin
         end
       end
    end

    assert_select ".form-tab-container.a-group-of-tabs .form-tab" do |tabs|
      assert_equal 2, tabs.size
      assert_equal "custom-tab-class form-tab", tabs.last.attributes["class"]
    end
    assert_select ".a-group-of-tabs .form-tab input"
  end

  test "tabbed blocks easy syntax" do
    the_form do |form|
       form.group(:type => :tabbed, :class=> "a-group-of-tabs") do
         form.tab(("personal_data"),:class => "parenttab") do
           form.text_field :lastname
           form.group(:type => :tabbed, :class=> "childtab") do
             form.tab(("inner tab"),:class =>"childtab") do
               form.text_field :is_admin
             end
           end
         end
         form.tab(("rights"), :class => "custom-tab-class") do
           form.check_box :is_admin
         end
       end
    end

    assert_select ".form-tab-container.a-group-of-tabs .form-tab" do |tabs|
      assert_equal 2, tabs.size
      assert_equal "custom-tab-class form-tab", tabs.last.attributes["class"]
    end
    assert_select ".a-group-of-tabs .form-tab input"

  end

  test "tabs can be unfolded" do
    original_value = Ubiquo::Settings.context(:ubiquo_form_builder).get(:unfold_tabs)
    Ubiquo::Settings.context(:ubiquo_form_builder).set(:unfold_tabs,true)
    begin
      the_form do |form|
         form.group(:type => :tabbed, :class=> "a-group-of-tabs") do
           form.tab(("personal_data")) do
             form.text_field :lastname
          end
         end
      end

      assert_select ".form-tab-container.a-group-of-tabs .form-tab", 0
      assert_select ".form-tab-container-unfolded.a-group-of-tabs .form-tab", 1
    ensure
      # Restore config
      Ubiquo::Settings.context(:ubiquo_form_builder).set(:unfold_tabs, original_value )
    end
  end

  test "we cannot call tab without a tabbed parent group defined" do
    assert_raise(RuntimeError) {
      the_form do |form|
         form.tab(t("personal_data")) do
           form.text_field :lastname
         end
      end
    }
  end

  test "can append content inside the field, after and before the content" do
    the_form do |form|
      form.text_field :lastname, :group => { :after => '<div class="after">A</div>'.html_safe }
      form.text_field :lastname, :class=> "alter", :group => { :before => '<div class="before">A</div>'.html_safe }
    end
    assert_select "form .form-item" do |form_items|
      assert_select form_items.first, ".after"
      assert_select form_items.first, "div *" do |items|
        assert_equal "after", items.last.attributes["class"]
      end
      assert_select form_items.last, ".before"
      assert_select form_items.last, "div *" do |items|
        assert_equal "before", items.first.attributes["class"]
      end
    end
  end

  test "use check_box with all options" do
    the_form do |form|
      # Weird use but useful sometimes
      form.check_box( :lastname )
      form.check_box( :lastname, {:class => "simple"})
      form.check_box( :lastname, {:class => "complex"}, "GARCIA", "OFF" )
    end
    assert_select "form input[type=hidden][value=0]",2
    assert_select "form input[type=checkbox][class=checkbox][value=1]"
    assert_select "form input[type=checkbox][class=simple][value=1]"
    assert_select "form input[type=hidden][value=OFF]"
    assert_select "form input[type=checkbox][class=complex][value=GARCIA]"
  end

  test "methods with an optional param which is an array" do
    # There are some methods like
    #   date_select(object_name, method, options = {}, html_options = {}) public
    # where our params must be passed/merged to html_options but there is a chance to work wrong,
    # and is the following:
    #
    #   date_select(object_name, method, {:foo => :bar, :class => "date_select"} )
    #
    # As you see if the implementation of the form builder adds the options to the last param if it's a hash, then
    # it will fit this case, but what we really want to be called is:
    #
    #   date_select(object_name, method, {:foo => :bar}, {:class => "date_select"} )
    #
    # To fix that we configure the builder to expect the hash in right position.

    # mock the default_options hash
    # Using marshal as a trick for deep clone
    old_options = Marshal.load(Marshal.dump(Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options))
    begin
      options = Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options
      options = options.deep_merge(
        :date_select => {:class => "date_select_class"},
        :datetime_select => {:class => "datetime_select_class"},
        :time_select => {:class => "time_select_class"},
        :collection_select => {:class => "collection_select"},
        :select => {:class => "select"},
        :time_zone_select => {:class => "time_zone_select"}
      )
      Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options = options
      the_form do |form|
        form.check_box( :lastname, :class => "checkboxed")
        # Forcing :order because of an unknown bug on I18n covnerting arrays to hashes
        form.datetime_select(:born_at,{:order =>[:day,:month,:year]})
        form.datetime_select(:born_at,{:order =>[:day,:month,:year]}, {:class => "datetime_forced"})
        form.date_select(:born_at, {:order =>[:day,:month,:year],:include_blank => true})
        form.time_select(:born_at)
        choices = [["Bar","Bar"],["Foo","Foo"]]
        form.collection_select(:lastname, choices,:first, :last )
        form.select(:lastname, choices )
        form.time_zone_select(:lastname)
      end

      assert_select "form .checkboxed"
      assert_select "form .date_select_class"
      assert_select "form .datetime_forced"
      assert_select "form .datetime_select_class"
      assert_select "form .time_select_class"
      assert_select "form .collection_select"
      assert_select "form .select"
      assert_select "form .time_zone_select"
    ensure
      # restore class variable
      Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options = old_options
    end
  end

  test "support calendar_date_select" do
    self.expects(:calendar_date_select).returns('<input name="calendar"/>')
    the_form do |form|
      form.calendar_date_select( :born_at )
    end
    assert_select "form .form-item.datetime label"
    assert_select "form .form-item.datetime input"
  end

  test "do not forward options as attributes" do
    the_form do |form|
      form.text_field :lastname, :group => { :class => "aclass", :attx => "attxvalue" }
      form.text_field :lastname, :label => "MYLABEL", :label_as_legend => true,
        :group => { :type => :fieldset, :class => "custom_class"}
    end
    assert_select "form *[group]", 0
    assert_select "fieldset[label]", 0
    assert_select "fieldset[legend]", 0
    assert_select "fieldset[label_as_legend]", 0
    assert_select "fieldset[class=custom_class]"
    assert_select "input[label_as_legend]", 0
  end

  test "media_selector merge the attributes" do
    previous_config = Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options[:text_field]
    Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options[:text_field] = {}
    begin
      Ubiquo::Helpers::UbiquoFormBuilder.initialize_method("text_field",
        { :group => {
            :type => :fieldset,
            :class => "group-related-assets"
          },
          :label_as_legend => true
        })
      the_form do |form|
        form.text_field :lastname,
          :group => {
            :class => "aclass",
            :before => "<span>Before!</span>"
          }
      end
      assert_select "form fieldset[class=aclass]"
      assert_select "form legend", "Lastname"
      assert_select "form fieldset span", "Before!"
    ensure
      Ubiquo::Helpers::UbiquoFormBuilder.default_tag_options[:text_field] = previous_config
    end
  end

  protected

  # helper to build a ubiquo form to test
  def the_form(options = {}, &proc)
    self.ubiquo.stubs(:users_path).returns("/ubiquo/users")
    self.ubiquo.stubs(:user_path).returns("/ubiquo/users/1")
    options[:url] = ubiquo.users_path
    options[:builder] = Ubiquo::Helpers::UbiquoFormBuilder
    render :text => form_for(User.new, options, &proc)
  end

end
