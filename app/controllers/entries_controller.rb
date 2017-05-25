class EntriesController < ApplicationController

  skip_before_action :verify_authenticity_token, only: [:push_view, :newsletter]
  skip_before_action :authorize, only: [:push_view, :newsletter]

  def index
    @user = current_user
    update_selected_feed!("collection_all")

    feed_ids = @user.subscriptions.pluck(:feed_id)
    entry_id_cache = EntryIdCache.new(@user.id, feed_ids)

    @entries = entry_id_cache.page(params[:page])
    @page_query = @entries

    @append = params[:page].present?

    @type = 'all'
    @data = nil

    @collection_title = 'All'

    respond_to do |format|
      format.js { render partial: 'shared/entries' }
    end
  end

  def unread
    @user = current_user
    update_selected_feed!('collection_unread')

    unread_entries = @user.unread_entries.select(:entry_id).page(params[:page]).sort_preference(@user.entry_sort)
    @entries = Entry.entries_with_feed(unread_entries, @user.entry_sort).entries_list

    @page_query = unread_entries

    @append = params[:page].present?

    @all_unread = 'true'
    @type = 'unread'
    @data = nil

    @collection_title = 'Unread'

    respond_to do |format|
      format.js { render partial: 'shared/entries' }
    end
  end

  def starred
    @user = current_user
    update_selected_feed!("collection_starred")

    starred_entries = @user.starred_entries.select(:entry_id).page(params[:page]).order("published DESC")
    @entries = Entry.entries_with_feed(starred_entries, "published DESC").entries_list

    @page_query = starred_entries

    @append = params[:page].present?

    @type = 'starred'
    @data = nil

    @collection_title = 'Starred'

    respond_to do |format|
      format.js { render partial: 'shared/entries' }
    end
  end

  def show
    @user = current_user
    @entries = entries_by_id(params[:id])
    respond_to do |format|
      format.js
      format.html do
        site_setup
        render 'site/logged_in'
      end
    end
  end

  def content
    @user = current_user
    @entry = Entry.find params[:id]

    @content_view = params[:content_view] == 'true'

    if @user.setting_on?(:sticky_view_inline)
      subscription = Subscription.where(user: @user, feed_id: @entry.feed_id).first
      if subscription.present?
        subscription.update_attributes(view_inline: @content_view)
      end
    end

    begin
      if @content_view
        url = @entry.fully_qualified_url
        @content_info = Rails.cache.fetch("content_view:#{Digest::SHA1.hexdigest(url)}:v5") do
          Librato.increment 'readability.first_parse'
          MercuryParser.parse(url)
        end
        @content = @content_info.content
        Librato.increment 'readability.parse'
      else
        @content = @entry.content
      end
    rescue => e
      @content = check_for_image(@entry, url)
    end

    begin
      @content = ContentFormatter.format!(@content, @entry, !@user.setting_on?(:disable_image_proxy))
    rescue
      @content = nil
    end
  end

  def preload
    @user = current_user
    ids = params[:ids].split(',').map {|i| i.to_i }
    entries = entries_by_id(ids)
    render json: entries.to_json
  end

  def mark_as_read
    @user = current_user
    UnreadEntry.where(user: @user, entry_id: params[:id]).delete_all
    UpdatedEntry.where(user: @user, entry_id: params[:id]).delete_all
    head :ok
  end

  def mark_all_as_read
    @user = current_user

    if params[:type] == 'feed'
      unread_entries = UnreadEntry.where(user_id: @user.id, feed_id: params[:data])
    elsif params[:type] == 'tag'
      feed_ids = @user.taggings.where(tag_id: params[:data]).pluck(:feed_id)
      unread_entries = UnreadEntry.where(user_id: @user.id, feed_id: feed_ids)
    elsif params[:type] == 'starred'
      starred = @user.starred_entries.pluck(:entry_id)
      unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: starred)
    elsif params[:type] == 'recently_read'
      recently_read = @user.recently_read_entries.pluck(:entry_id)
      unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: recently_read)
    elsif params[:type] == 'updated'
      updated = @user.updated_entries.pluck(:entry_id)
      unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: updated)
      @user.updated_entries.delete_all
    elsif  %w{unread all}.include?(params[:type])
      unread_entries = UnreadEntry.where(user_id: @user.id)
    elsif params[:type] == 'saved_search'
      saved_search = @user.saved_searches.where(id: params[:data]).first
      if saved_search.present?
        params[:query] = saved_search.query
        ids = matched_search_ids(params)
        unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: ids)
      end
    elsif params[:type] == 'search'
      params[:query] = params[:data]
      ids = matched_search_ids(params)
      unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: ids)
    end

    if params[:date].present?
      unread_entries = unread_entries.where('created_at <= :last_unread_date', {last_unread_date: params[:date]})
    end

    unread_entries.delete_all if unread_entries

    if params[:ids].present?
      ids = params[:ids].split(',').map(&:to_i)
      UnreadEntry.where(user_id: @user.id, entry_id: ids).delete_all
    end

    @mark_selected = true
    get_feeds_list

    respond_to do |format|
      format.js
    end
  end

  def mark_direction_as_read
    @user = current_user
    ids = params[:ids].split(',').map {|i| i.to_i }
    if params[:direction] == 'above'
      unread_entries = UnreadEntry.where(user: @user, entry_id: ids)
      if params[:type] == 'updated'
        @user.updated_entries.where(entry_id: ids).delete_all
      end
    else
      if params[:type] == 'feed'
        unread_entries = UnreadEntry.where(user: @user, feed_id: params[:data]).where.not(entry_id: ids)
      elsif params[:type] == 'tag'
        feed_ids = @user.taggings.where(tag_id: params[:data]).pluck(:feed_id)
        unread_entries = UnreadEntry.where(user: @user, feed_id: feed_ids).where.not(entry_id: ids)
      elsif params[:type] == 'starred'
        starred = @user.starred_entries.pluck(:entry_id)
        unread_entries = UnreadEntry.where(user: @user, entry_id: starred).where.not(entry_id: ids)
      elsif params[:type] == 'updated'
        updated = @user.updated_entries.pluck(:entry_id)
        unread_entries = UnreadEntry.where(user: @user, entry_id: updated).where.not(entry_id: ids)
        @user.updated_entries.where.not(entry_id: ids).delete_all
      elsif  %w{unread all}.include?(params[:type])
        unread_entries = UnreadEntry.where(user: @user).where.not(entry_id: ids)
      elsif params[:type] == 'saved_search'
        saved_search = @user.saved_searches.where(id: params[:data]).first
        if saved_search.present?
          params[:query] = saved_search.query
          search_ids = matched_search_ids(params)
          ids = search_ids - ids
          unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: ids)
        end
      elsif params[:type] == 'search'
        params[:query] = params[:data]
        search_ids = matched_search_ids(params)
        ids = search_ids - ids
        unread_entries = UnreadEntry.where(user_id: @user.id, entry_id: ids)
      end
    end

    entry_ids = unread_entries.map(&:entry_id)
    unread_entries.delete_all

    @mark_selected = true
    get_feeds_list

    respond_to do |format|
      format.js
    end
  end

  def search
    @user = current_user
    @escaped_query = params[:query].gsub("\"", "'").html_safe if params[:query]

    @entries = Entry.scoped_search(params, @user)
    @page_query = @entries
    @total_results = @entries.total

    @append = params[:page].present?

    @type = 'all'
    @data = nil

    @search = true

    @collection_title = 'Search'

    @saved_search = SavedSearch.new

    respond_to do |format|
      format.js { render partial: 'shared/entries' }
    end
  end

  def push_view
    user_id = verify_push_token(params[:user])
    @user = User.find(user_id)
    @entry = Entry.find(params[:id])
    UnreadEntry.where(user: @user, entry: @entry).delete_all
    redirect_to @entry.fully_qualified_url, status: :found
  end

  def diff
    @entry = Entry.find(params[:id])
    if @entry.original && @entry.original['content'].present?
      begin
        before = ContentFormatter.format!(@entry.original['content'], @entry, !@user.setting_on?(:disable_image_proxy))
        after = ContentFormatter.format!(@entry.content, @entry, !@user.setting_on?(:disable_image_proxy))
        @content = HTMLDiff::Diff.new(before, after).inline_html.html_safe
      rescue HTML::Pipeline::Filter::InvalidDocumentException
        @content = '(comparison error)'
      end
    end
  end

  def newsletter
    @entry = Entry.where(public_id: params[:id]).take!
    render layout: nil
  end

  private

  def entries_by_id(entry_ids)
    entries = Entry.where(id: entry_ids).includes(feed: [:favicon])
    entries.each_with_object({}) do |entry, hash|
      locals = {
        entry: entry,
        services: sharing_services(entry),
        content_view: false,
        user: @user
      }
      hash[entry.id] = {
        content: render_to_string(partial: "entries/show", formats: [:html], locals: locals),
        feed_id: entry.feed_id
      }
    end
  end

  def sharing_services(entry)
    @user_sharing_services ||= begin
      (@user.sharing_services + @user.supported_sharing_services).reject {|sharing_service| sharing_service.active? == false }.sort_by{|sharing_service| sharing_service.label}
    end

    services = []
    @user_sharing_services.each do |sharing_service|
      begin
        services << sharing_service.link_options(entry)
      rescue
      end
    end
    services
  end

  def matched_search_ids(params)
    params[:load] = false
    query = params[:query]
    entries = Entry.scoped_search(params, @user)
    ids = entries.results.map(&:id)
    if entries.total_pages > 1
      2.upto(entries.total_pages) do |page|
        params[:page] = page
        params[:query] = query
        entries = Entry.scoped_search(params, @user)
        ids = ids.concat(entries.results.map(&:id))
      end
    end
    ids
  end

  def check_for_image(entry, url)
    response = HTTParty.head(url)
    if response.headers['content-type'] =~ /^image\//
      content = "<img src='#{url}' />"
      Librato.increment 'readability.image_found'
    else
      content = nil
      Librato.increment 'readability.parse_fail'
    end
    content
  end

end
