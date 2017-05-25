class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper

  before_action :authorize
  before_action :set_user
  before_action :honeybadger_context
  after_action :set_csrf_cookie

  etag { current_user.try :id }

  add_flash_types :analytics_event, :one_time_content

  def append_info_to_payload(payload)
    super
    payload[:feedbin_request_id] = request.headers['X-Feedbin-Request-ID']
  end

  def update_selected_feed!(type, data = nil)
    if data.nil?
      selected_feed = type
    else
      session[:selected_feed_data] = data
      selected_feed = "#{type}_#{data}"
    end
    session[:selected_feed_type] = type
    session[:selected_feed] = selected_feed
  end

  def render_404
    render 'errors/not_found', status: 404, layout: 'application', formats: [:html]
  end

  def get_collections
    user = current_user
    collections = []
    collections << {
      title: 'Unread',
      path: unread_entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_unread',
      favicon_class: 'favicon-unread',
      parent_class: 'collection-unread',
      parent_data: { behavior: 'all_unread', feed_id: 'collection_unread', count_type: 'unread' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'unread', message: 'Mark all items as read?'}.to_json }
    }
    collections << {
      title: 'All',
      path: entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_all',
      favicon_class: 'favicon-all',
      parent_class: 'collection-all',
      parent_data: { behavior: 'all_unread', feed_id: 'collection_all', count_type: 'unread' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'all', message: 'Mark all items as read?'}.to_json }
    }
    collections << {
      title: 'Starred',
      path: starred_entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_starred',
      favicon_class: 'favicon-star',
      parent_class: 'collection-starred',
      parent_data: { behavior: 'starred', feed_id: 'collection_starred', count_type: 'starred' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'starred', message: 'Mark starred items as read?'}.to_json }
    }
    if !user.setting_on?(:hide_recently_read)
      collections << {
        title: 'Recently Read',
        path: recently_read_entries_path,
        count_data: nil,
        id: 'collection_recently_read',
        favicon_class: 'favicon-recently-read',
        parent_class: 'collection-recently-read',
        parent_data: { behavior: 'recently_read', feed_id: 'collection_recently_read', count_type: 'recently_read' },
        data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'recently_read', message: 'Mark recently read items as read?'}.to_json }
      }
    end
    if !user.setting_on?(:hide_updated)
      collections << {
        title: 'Updated',
        path: updated_entries_path,
        count_data: {behavior: 'needs_count', count_group: 'all', count_collection: 'updated', count_hide: 'on'},
        id: 'collection_updated',
        favicon_class: 'favicon-updated',
        parent_class: 'collection-updated',
        parent_data: { behavior: 'updated', feed_id: 'collection_updated', count_type: 'updated' },
        data: { behavior: 'selectable show_entries open_item feed_link', special_collection: 'updated', mark_read: {type: 'updated', message: 'Mark updated items as read?'}.to_json }
      }
    end
    collections
  end

  def get_feeds_list
    @mark_selected = true
    @user = current_user

    excluded_feeds = @user.taggings.pluck(:feed_id).uniq
    @feeds = @user.feeds.where.not(id: excluded_feeds).includes(:favicon).include_user_title

    @count_data = {
      unread_entries: @user.unread_entries.pluck('feed_id, entry_id'),
      starred_entries: @user.starred_entries.pluck('feed_id, entry_id'),
      updated_entries: @user.updated_entries.pluck('feed_id, entry_id'),
      tag_map: @user.taggings.build_map,
      entry_sort: @user.entry_sort
    }
    @feed_data = {
      feeds: @feeds,
      collections: get_collections,
      tags: @user.tag_group,
      saved_searches: @user.saved_searches.order("lower(name)"),
      count_data: @count_data,
      feed_order: @user.feed_order
    }
  end

  def render_file_or(file, status, &block)
    if ENV['SITE_PATH'].present? && File.exist?(File.join(ENV['SITE_PATH'], file))
      render file: File.join(ENV['SITE_PATH'], file), status: status, layout: nil
    else
      yield
    end
  end

  def set_csrf_cookie
    cookies['XSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
  end

  def site_setup
    get_feeds_list
    subscriptions = @user.subscriptions

    user_titles = subscriptions.each_with_object({}) do |subscription, hash|
      if subscription.title.present?
        hash[subscription.feed_id] = ERB::Util.html_escape_once(subscription.title)
      end
    end

    readability_settings = subscriptions.each_with_object({}) do |subscription, hash|
      hash[subscription.feed_id] = subscription.view_inline
    end

    @show_welcome = (subscriptions.present?) ? false : true
    @classes = user_classes
    @data = {
      login_url: login_url,
      tags_path: tags_path(format: :json),
      user_titles: user_titles,
      preload_entries_path: preload_entries_path(format: :json),
      sticky_readability: @user.setting_on?(:sticky_view_inline),
      readability_settings: readability_settings,
      show_unread_count: @user.setting_on?(:show_unread_count),
      precache_images: @user.setting_on?(:precache_images),
      auto_update_path: auto_update_feeds_path,
      font_sizes: Feedbin::Application.config.font_sizes,
      mark_as_read_path: mark_all_as_read_entries_path,
      mark_as_read_confirmation: @user.setting_on?(:mark_as_read_confirmation),
      mark_direction_as_read_entries: mark_direction_as_read_entries_path,
      entry_sort: @user.entry_sort,
      update_message_seen: @user.setting_on?(:update_message_seen),
      feed_order: @user.feed_order,
      refresh_sessions_path: refresh_sessions_path
    }
  end

  protected

  def verified_request?
    super || valid_authenticity_token?(session, request.headers['X-XSRF-TOKEN'])
  end

  private

  def set_user
    @user = current_user
  end

  def feeds_response
    if 'view_all' == @user.get_view_mode
      entry_id_cache = EntryIdCache.new(@user.id, @feed_ids)
      @entries = entry_id_cache.page(params[:page])
      @page_query = @entries
    elsif 'view_starred' == @user.get_view_mode
      starred_entries = @user.starred_entries.select(:entry_id).where(feed_id: @feed_ids).page(params[:page]).order("published DESC")
      @entries = Entry.entries_with_feed(starred_entries, 'DESC').entries_list
      @page_query = starred_entries
    else
      @all_unread = 'true'
      unread_entries = @user.unread_entries.select(:entry_id).where(feed_id: @feed_ids).page(params[:page]).sort_preference(@user.entry_sort)
      @entries = Entry.entries_with_feed(unread_entries, @user.entry_sort).entries_list
      @page_query = unread_entries
    end
  end

  def honeybadger_context
    Honeybadger.context(user_id: current_user.id) if current_user
  end

  def verify_push_token(authentication_token)
    authentication_token = CGI::unescape(authentication_token)
    verifier = ActiveSupport::MessageVerifier.new(Feedbin::Application.config.secret_key_base)
    verifier.verify(authentication_token)
  end

  def user_classes
    @classes = []
    @classes.push("theme-#{@user.theme || 'day'}")
    @classes.push(@user.get_view_mode)
    @classes.push(@user.entry_width)
    @classes.push("entries-body-#{@user.entries_body || '1'}")
    @classes.push("entries-time-#{@user.entries_time || '1'}")
    @classes.push("entries-feed-#{@user.entries_feed || '1'}")
    @classes.push("entries-image-#{@user.entries_image || '1'}")
    @classes.push("entries-display-#{@user.entries_display || 'block'}")
    @classes = @classes.join(" ")
  end

end
