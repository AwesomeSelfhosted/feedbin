require 'kramdown'
require 'rails_autolink'

class ContentFormatter

  def self.format!(content, entry = nil, image_proxy_enabled = true)
    whitelist = Feedbin::Application.config.whitelist.clone
    transformers = [iframe_whitelist, class_whitelist] + whitelist[:transformers]
    whitelist[:transformers] = transformers

    context = {
      whitelist: whitelist
    }
    filters = [HTML::Pipeline::LazyLoadFilter, HTML::Pipeline::SanitizationFilter]

    if ENV['CAMO_HOST'] && ENV['CAMO_KEY'] && image_proxy_enabled
      context[:asset_proxy] = ENV['CAMO_HOST']
      context[:asset_proxy_secret_key] = ENV['CAMO_KEY']
      filters = filters << HTML::Pipeline::CamoFilter
    end

    if entry
      filters.unshift(HTML::Pipeline::AbsoluteSourceFilter)
      filters.unshift(HTML::Pipeline::AbsoluteHrefFilter)
      # filters.push(HTML::Pipeline::ImagePlaceholderFilter)
      context[:image_base_url] = context[:href_base_url] = entry.feed.site_url
      context[:image_subpage_url] = context[:href_subpage_url] = entry.url || ""
      context[:placeholder_url] = self.placeholder_url
      context[:placeholder_attribute] = "data-feedbin-src"
    end

    pipeline = HTML::Pipeline.new filters, context

    result = pipeline.call(content)
    result[:output].to_s
  end

  def self.absolute_source(content, entry)
    filters = [HTML::Pipeline::AbsoluteSourceFilter, HTML::Pipeline::AbsoluteHrefFilter]
    context = {
      image_base_url: entry.feed.site_url,
      image_subpage_url: entry.url || "",
      href_base_url: entry.feed.site_url,
      href_subpage_url: entry.url || ""
    }
    pipeline = HTML::Pipeline.new filters, context
    result = pipeline.call(content)
    result[:output].to_s
  rescue
    content
  end

  def self.api_format(content, entry)
    filters = [HTML::Pipeline::AbsoluteSourceFilter, HTML::Pipeline::AbsoluteHrefFilter, HTML::Pipeline::ProtocolFilter]
    context = {
      image_base_url: entry.feed.site_url,
      image_subpage_url: entry.url || "",
      href_base_url: entry.feed.site_url,
      href_subpage_url: entry.url || ""
    }
    pipeline = HTML::Pipeline.new filters, context
    result = pipeline.call(content)
    result[:output].to_s
  rescue
    content
  end

  def self.app_format(content, entry)
    filters = [HTML::Pipeline::AbsoluteSourceFilter, HTML::Pipeline::AbsoluteHrefFilter, HTML::Pipeline::ProtocolFilter, HTML::Pipeline::ImagePlaceholderFilter]
    context = {
      image_base_url: entry.feed.site_url,
      image_subpage_url: entry.url || "",
      href_base_url: entry.feed.site_url,
      href_subpage_url: entry.url || "",
      placeholder_url: "",
      placeholder_attribute: "data-feedbin-src"
    }
    pipeline = HTML::Pipeline.new filters, context
    result = pipeline.call(content)
    result[:output].to_s
  rescue
    content
  end

  def self.evernote_format(content, entry)
    filters = [HTML::Pipeline::SanitizationFilter, HTML::Pipeline::AbsoluteSourceFilter, HTML::Pipeline::AbsoluteHrefFilter, HTML::Pipeline::ProtocolFilter]
    context = {
      whitelist: Feedbin::Application.config.evernote_whitelist.clone,
      image_base_url: entry.feed.site_url,
      image_subpage_url: entry.url || "",
      href_base_url: entry.feed.site_url,
      href_subpage_url: entry.url || ""
    }

    pipeline = HTML::Pipeline.new filters, context
    result = pipeline.call(content)
    result[:output].to_xml
  rescue
    content
  end

  def self.summary(content)
    sanitize_config = Sanitize::Config::BASIC.dup
    sanitize_config = sanitize_config.merge(remove_contents: ['script', 'style', 'iframe', 'object', 'embed'])
    content = Sanitize.fragment(content, sanitize_config)
    ApplicationController.helpers.sanitize(content, tags: []).truncate(86, :separator => " ").squish
  rescue
    ''
  end

  def self.iframe_whitelist
    lambda { |env|
      node      = env[:node]
      node_name = env[:node_name]
      source    = node['src']

      if node_name != 'iframe' || env[:is_whitelisted] || !node.element? || source.nil?
        return
      end

      allowed_hosts = [
        /^
          (?:https?:\/\/|\/\/)
          (?:www\.)?
          (?:youtube\.com|youtu\.be|youtube-nocookie\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:www\.|player\.)?
          (?:vimeo\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:www\.)?
          (?:kickstarter\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:embed\.spotify\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:w\.soundcloud\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:view\.vzaar\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:vine\.co)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:e\.)?
          (?:infogr\.am)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:i\.)?
          (?:embed\.ly)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:cdn\.)?
          (?:embedly\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:www\.flickr\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:mpora\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:embed-ssl\.ted\.com)
        /x,
        /^
          (?:https?:\/\/|\/\/)
          (?:www\.tumblr\.com)
        /x
      ]

      source_allowed = false
      allowed_hosts.each do |host|
        if source =~ host
          source_allowed = true
        end
      end

      return unless source_allowed

      # Force protocol relative url
      node['src'] = source.gsub(/^https?:?/, '')

      # Strip attributes
      Sanitize.clean_node!(node, {
        :elements => %w[iframe],
        :attributes => {
          'iframe'  => %w[allowfullscreen frameborder height src width]
        }
      })

      {:node_whitelist => [node]}
    }
  end

  def self.class_whitelist
    lambda do |env|
      node = env[:node]

      if env[:node_name] != 'blockquote' || env[:is_whitelisted] || !node.element? || node['class'].nil?
        return
      end

      allowed_classes = ['twitter-tweet', 'instagram-media']

      allowed_attributes = []

      allowed_classes.each do |allowed_class|
        if node['class'].include?(allowed_class)
          node['class'] = allowed_class
          allowed_attributes = ['class', :data]
        end
      end

      whitelist = Feedbin::Application.config.whitelist.clone
      whitelist[:attributes]['blockquote'] = allowed_attributes

      Sanitize.clean_node!(node, whitelist)

      {:node_whitelist => [node]}
    end
  end

  def self.placeholder_url
    @placeholder_url ||= ActionController::Base.helpers.asset_path("placeholder.png")
  end

  def self.text_email(content)
    content = Kramdown::Document.new(content).to_html
    ActionController::Base.helpers.auto_link(content)
  rescue
    content
  end

end
