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
    attribute :_rev,              String
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

    before_save do
      ret = calc_rev
      @rev_changed = ret != _rev 
      self._rev = ret
    end

    after_save do
      _keys = [Oahu::Index::ALL_KEY]
      _keys.concat(self.class.index_keys.map { |k| [k, self.send(k.to_sym).to_s].join(":") if self.respond_to?(k.to_sym) } ) if self.class.respond_to?(:index_keys)
      _index.add(id, _keys)
    end

    after_destroy do
      _index.remove(id)
    end

    def self.path id
      "#{self.name.pluralize.underscore}/#{id}"
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
      elsif attrs.is_a?(Array)
        attrs.map { |a| find_one(a) }
      else
        find_one(attrs.to_s)
      end
    end

    def self.find_one _id
      get(_id) || create(Oahu.get(path(_id)))
    end

    def self.sync
      Oahu.get(self.name.demodulize.pluralize.underscore, :limit => 0).map do |attrs|
        rec_id = attrs.delete "id"
        rec = get(rec_id) || new(:id => rec_id)
        rec.update_attributes(attrs)
      end
    end

    def fetch
      sync
    end

    def _index
      self.class._index
    end

    def rev
      calc_rev
    end

    def calc_rev
      Digest::SHA1.hexdigest([self.class.name, id.to_s, updated_at.to_s].join(":"))
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
   
    # attribute :project_ids, Array
    list :projects
    
    after_create :sync

    def sync
      __rev = ["updated_at"]
      project_ids.map do |i| 
        p = Project.find(i)
        __rev << p.rev unless p.nil?
      end
      self._rev = Digest::SHA1.hexdigest(__rev.flatten.join("-"))
      save
      self
    end

    def self.index_keys
      ["name"]
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
    attribute :paths, Hash
    
    def self.path id
      "projects/#{project_id}"
    end

    def project
      Project.find(project_id)
    end
  end

  class ResourceList < Resource
    def calc_rev
      ret = [super] + items.map { |i| i.rev rescue nil }.compact
      Digest::SHA1.hexdigest ret.join("-")
    end
  end

  module Resources

    class Image < Resource
    end

    class Video < Resource
      attribute :encoding, String

      def calc_rev
        play_count = stats['play']['t'] rescue 0
        [super, play_count].compact.join("-")
      end
      
    end

    class ImageList < ResourceList
      list :images, Oahu::Resources::Image
      # attribute :image_ids, Array
      # def images
      #   image_ids.map { |i| Image.get(i) }.compact
      # end
      alias :items :images
    end

    class VideoList < ResourceList
      # attribute :video_ids, Array
      list :videos, Oahu::Resources::Video
      # def videos
      #   video_ids.map { |i| v = Video.find(i); v unless v.encoding != "finished" }.compact
      # end
      alias :items :videos
    end
  end

  class Project < Model
    
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

    list :pub_accounts,           Oahu::PubAccount
    list :images,                 Oahu::Resources::Image
    list :videos,                 Oahu::Resources::Video
    list :video_lists,            Oahu::Resources::VideoList
    list :image_lists,            Oahu::Resources::ImageList
    list :apps,                   Oahu::App

    def self.index_keys
      [:slug]
    end

    def self.path id
      "projects/#{id}"
    end

    def self.all_by_year
      all.inject({}) do |pp, p|
        if p.release_date
          if year = p.release_date.year
            pp[year] ||= []
            pp[year] << p
          end
        end
        pp
      end
    end

    def self.sync(filters={ :published => true })
      Oahu.log("Projects Sync start")
      Oahu.get("projects", filters: filters, limit: 0).map { |attrs| (find(attrs['id']) || create(attrs)).sync(attrs) }
    end

    # after_create :sync

    def sync attrs={}
      puts "Calling sync on Project: #{self.slug}, with rev: Stored rev: #{_rev}, Calc rev:((#{calc_rev}))"
      attrs = Oahu.get("projects/#{id}") if attrs.blank?
      sync_list(:resources)
      sync_list(:pub_accounts)
      sync_list(:apps)
      puts "Before update: Stored rev: #{_rev}, Calc rev:((#{calc_rev}))"
      update_attributes(attrs)
      puts "After update: Stored rev: #{_rev}, Calc rev:((#{calc_rev}))"
      self
    end

    def sync_list(what)
      rev = [what.to_s]
      _lists = {}
      Oahu.log("Project #{what} Sync start [#{id}]", :debug)
      ret = Oahu.get("projects/#{id}/#{what}", limit: 0)
      ret.sort_by { |r| r['_type'] }.map do |attrs|
        klass = "Oahu::#{attrs["_type"]}".constantize rescue nil
        klass = Oahu.const_get(what.to_s.singularize.camelize) unless klass.respond_to? :create
        list_name = klass.name.demodulize.pluralize.underscore.to_sym
        if respond_to?(list_name)
          o = klass.create(attrs)
          _lists[list_name] ||= []
          _lists[list_name] << o
        end
      end
      _lists.map { |ln,ll| send("#{ln}=", ll) }
    end

    def default_video
      Oahu::Resources::Video.get(default_video_id) unless default_video_id.nil?
    end

    def default_image
      Oahu::Resources::Image.get(default_image_id) unless default_image_id.nil?
    end

    def credits_by_job(job)
      (credits || []).select { |c| c['job']  == job }.map { |c| c['name'] }
    end

    def self.by_slug slug
      find_by(:slug, slug)
    end

  end

end
