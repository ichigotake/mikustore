# -*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "utils"))

module Plugin::Mikustore
  class PluginDetail < Gtk::VBox

    attr_reader :plugin_name, :description, :requirements, :install_button, :latest_version, :author
    attr_reader :requirement_mikutter, :requirement_plugin
    attr_reader :package

    def initialize
      super
      @package = nil
      @plugin_name = Gtk::Label.new
      @description = Gtk::IntelligentTextview.new
      @latest_version = Gtk::Label.new
      @author = Gtk::HBox.new
      @requirements = Gtk::Table.new(2, 2)
      @install_button = Gtk::Button.new("インストール")
      @requirement_mikutter = Gtk::Label.new
      @requirement_plugin = Gtk::Label.new
      @requirements.
        attach(caption("mikutterのバージョン").left, 0, 1, 0, 1).
        attach(caption("依存するプラグイン").left, 0, 1, 1, 2).
        attach(@requirement_mikutter.left, 1, 2, 0, 1).
        attach(@requirement_plugin.left, 1, 2, 1, 2).
        set_row_spacing(0, 4).
        set_row_spacing(1, 4).
        set_column_spacing(0, 16)
      @install_button.ssc(:clicked) {
        install_package {
          @install_button.sensitive = false
        }
        true }
      @install_button.sensitive = false

      requirements_group = Gtk::Frame.new.set_border_width(8)
      requirements_group.set_label_widget(caption("依存関係"))

      closeup @plugin_name
      closeup @description
      closeup Gtk::HBox.new.closeup(caption("最新バージョン")).add(@latest_version)
      closeup requirements_group.add(@requirements)
      closeup Gtk::VBox.new.closeup(caption("開発者").left).closeup(@author)
      closeup @install_button
    end

    # パッケージが選択された時。画面を書き換える
    def set_package(new_package)
      type_strict new_package => Hash
      @package = new_package
      plugin_name.set_markup("<span size=\"x-large\" weight=\"bold\">#{package[:name]}</span>")
      description.rewind(package[:description])
      latest_version.set_text((package[:version] || "なし").to_s)
      requirement_mikutter.set_text(package[:depends][:mikutter].to_s)
      if(package[:depends][:plugin])
        requirement_plugin.set_text(package[:depends][:plugin].join(","))
      else
        requirement_plugin.set_text("指定なし")
      end
      if Plugin::Mikustore::Utils.installed_version(package[:slug].to_sym)
        install_button.sensitive = false
        install_button.set_label("インストール済")
      else
        install_button.sensitive = true
        install_button.set_label("インストール") end
      author.children.each{ |c| author.remove(c) }
      author_box = Gtk::HBox.new(false, 4)
      author.add(author_box)
      Thread.new{ User.findbyidname(package[:author]) }.next{ |user|
        if not author_box.destroyed?
          author_box.closeup Gtk::WebIcon.new(user[:profile_image_url], 32, 32)
          author_box.add Gtk::IntelligentTextview.new("@#{user[:idname]} #{user[:name]}\n#{user[:statuses_count]} tweets, #{user[:favourites_count]}favs")
          author_box.show_all
        end
      }.terminate("ユーザ #{package[:author]} の情報を取得できませんでした")
    end
    alias :package= :set_package

    private

    def install_package
      install_button.sensitive = false
      install_button.set_label("インストール中")
      plugin_dir = "~/.mikutter/plugin/#{package[:slug]}/"
      plugin_main_file = "#{plugin_dir}#{package[:slug]}.rb"
      if FileTest.exist?(plugin_dir)
        return false end
      Thread.new {
        if not system("git clone #{package[:repository]} #{plugin_dir}")
          Deferred.fail($?) end
      }.next {
        notice "plugin load: #{plugin_main_file}"
        Plugin.load_file(plugin_main_file, package)
      }.next {
        install_button.set_label("インストール済")
        Plugin.call(:mikustore_plugin_installed, package[:slug])
      }.trap {
        install_button.sensitive = true
        install_button.set_label("インストール")
        if FileTest.exist?(plugin_dir)
          FileUtils.rm_rf(plugin_dir) end
      }
    end

    def caption(text)
      Gtk::Label.new.set_markup("<b>#{text}</b>")
    end
  end
end

