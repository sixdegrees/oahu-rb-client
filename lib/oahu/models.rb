require 'digest/sha1'
require 'toystore'

module Oahu


  module Store
    
    extend ActiveSupport::Concern

    included do 
      include Toy::Store

      adapter_name, adapter_args = Oahu.store_adapter
      adapter_klass = Toy.const_get(adapter_name.camelize) rescue nil
      
      include adapter_klass if adapter_klass

      adapter *Oahu.store_adapter

    end
  end

  class Model

    include Oahu::Store

    attribute :id,                String
    attribute :_type,             String
    attribute :slug,              String
    attribute :tags,              Array
    attribute :published,         Boolean
    attribute :name,              String
    attribute :description,       String
    attribute :created_at,        Time
    attribute :updated_at,        Time
    attribute :likes,             Integer
    attribute :stats,             Hash
    attribute :url,               String

    after_save do
      _keys = [Oahu::Index::ALL_KEY]
      _keys.concat(self.class.index_keys.map { |k| [k, self.send(k.to_sym).to_s].join(":") if self.respond_to?(k.to_sym) } ) if self.class.respond_to?(:index_keys)
      _index.add(id, _keys)
    end

    after_destroy do
      _index.remove(id)
    end

    def self.path id
      "#{self.class.name.pluralize.underscore}/#{id}"
    end

    def self.all
      _index.all
    end

    def self._index
      idx_id = "_idx_#{self.name}"
      ret = Index.get(idx_id)
      ret ||= Index.create(:id => idx_id, :klass_name => self.name)
      ret
    end

    def self.find_by key, val, find_one=true
      ret = self._index.find([key, val].join(":"))
      ret = ret.first if find_one
      ret
    end

    def self.find attrs
      if attrs.is_a?(Hash)
      else
        id = attrs.to_s
        get(attrs) || create(Oahu.get(path(id)))
      end
    end

    def self.sync
      Oahu.get(self.name.demodulize.pluralize.underscore, :limit => 0).map do |attrs|
        create(attrs)
      end
    end

    def fetch
      sync
    end

    def _index
      self.class._index
    end

    def rev
      respond_to?(:_rev) ? _rev : Digest::SHA1.hexdigest([self.class.name, id.to_s, updated_at.to_s].join(":"))
    end

  end


  class Index
    ALL_KEY = "__all__"
    include Oahu::Store

    attribute :idx,   Hash
    attribute :klass_name, String
    attribute :_type, String, :default => "Oahu::Index"

    def klass
      klass_name.constantize
    end

    def add i, ts=[ALL_KEY]
      Oahu.log("Adding Key #{i} to #{ts.inspect} in index: #{self.id}", :debug)
      remove(i)
      ts = Array(ts)
      ts.push(ALL_KEY) unless ts.include?(ALL_KEY)
      ts.each do |t|
        idx[t] ||= []
        idx[t].push i
        idx[t]
      end
      save
    end
    
    def remove i
      idx.map { |k,v| v.delete(i) }
      save
    end

    def find(t)
      (idx[t] || []).map { |i| klass.find(i) }.compact 
    end

    def all
      find(ALL_KEY)
    end

  end

  class ProjectList < Model
    
    attribute :_rev, String
    attribute :project_ids, Array
    
    after_create :sync

    def sync
      __rev = ["updated_at"]
      project_ids.map do |i| 
        p = Project.find(i)
        __rev << p.rev unless p.nil?
      end
      self._rev = Digest::MD5.hexdigest(__rev.flatten.join("-"))
      save
      self
    end

    def self.index_keys
      ["name"]
    end

    def projects
      project_ids.map { |i| Project.find(i) }.compact  
    end
  end

  class App < Model

    attribute :homepage,        String
    attribute :project_id,      String
    attribute :starts_at,       Time
    attribute :ends_at,         Time
    attribute :stylesheet_url,  String
    attribute :callback_url,    String
    attribute :extra,           Hash
    attribute :players_count,   Integer

    def self.live
      self.all.select { |a| a.live? }
    end

    def live?
      return false unless starts_at
      return false if starts_at > Time.now
      return false if ends_at && ends_at < Time.now
      true
    end

  end

  class PubAccount < Model
    attribute :project_id, String    
  end

  class Resource < Model
    attribute :project_id, String
    
    def self.path id
      "projects/#{project_id}"
    end

    def project
      Project.find(project_id)
    end
  end

  class ResourceList < Resource
  end

  module Resources

    class Image < Resource
      attribute :paths, Hash
    end

    class Video < Resource
      attribute :paths, Hash
      attribute :encoding, String
    end

    class ImageList < ResourceList
      attribute :image_ids, Array
      def images
        image_ids.map { |i| Image.get(i) }.compact
      end
    end

    class VideoList < ResourceList
      attribute :video_ids, Array
      def videos
        video_ids.map { |i| v = Video.get(i); v unless v.encoding != "finished" }.compact
      end
    end
  end

  class Project < Model
    
    attribute :_rev,              String
    attribute :_type,             String
    attribute :countries,         Array
    attribute :credits,           Array
    attribute :genres,            Array
    attribute :release_date,      Date
    attribute :synopsis,          String
    attribute :title,             String
    attribute :stylesheet_url,    String
    attribute :homepage,          String
    attribute :slug,              String
    attribute :default_image_id,  String
    attribute :default_video_id,  String
    attribute :links,             Array
    attribute :credits,           Array

    list :images,                 Oahu::Resources::Image
    list :videos,                 Oahu::Resources::Video
    list :video_lists,            Oahu::Resources::VideoList
    list :image_lists,            Oahu::Resources::ImageList
    list :apps,                   Oahu::App
    list :pub_accounts,           Oahu::PubAccount

    def self.index_keys
      [:slug]
    end

    def self.path id
      "projects/#{id}"
    end

    def self.sync(filters={ :published => true })
      Oahu.log("Projects Sync start")
      Oahu.get("projects", filters: filters, limit: 0).map { |attrs| create(attrs).sync }
    end

    # after_create :sync

    def sync
      __rev = [updated_at]
      __rev << sync_list(:resources)
      __rev << sync_list(:pub_accounts)
      __rev << sync_list(:apps)
      self._rev = Digest::MD5.hexdigest(__rev.flatten.join("-"))
      save
      self
    end
 
    def sync_list(what)
      rev = [what.to_s]
      Oahu.log("Project #{what} Sync start [#{id}]", :debug)
      Oahu.get("projects/#{id}/#{what}", limit: 0).map do |attrs|
        klass = "Oahu::#{attrs["_type"]}".constantize rescue nil
        klass = Oahu.const_get(what.to_s.singularize.camelize) unless klass.respond_to? :create
        list_name = klass.name.demodulize.pluralize.underscore.to_sym
        if respond_to?(list_name)
          o = klass.create(attrs)
          send(list_name).send :<<, o
          rev << o.rev
        end
      end
      Digest::MD5.hexdigest rev.sort.join("-")
    end

  end

end
