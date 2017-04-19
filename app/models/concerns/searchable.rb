module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    mappings _source: {enabled: false} do
      indexes :id,        type: 'long', index: :not_analyzed
      indexes :title,     analyzer: 'snowball'
      indexes :content,   analyzer: 'snowball'
      indexes :author,    analyzer: 'keyword'
      indexes :url,       analyzer: 'keyword'
      indexes :feed_id,   type: 'long', index: :not_analyzed, include_in_all: false
      indexes :published, type: 'date', include_in_all: false
      indexes :updated,   type: 'date', include_in_all: false
    end

    def self.scoped_search(params, user)
      params = build_search(params)
      options = {
        query: params[:query],
        sort: "desc",
        starred_ids: [],
        ids: [],
        not_ids: [],
        feed_ids: [],
      }

      if params[:sort] && %w{desc asc relevance}.include?(params[:sort])
        options[:sort] = params[:sort]
      end

      if params[:read] == false
        options[:ids].push(user.unread_entries.pluck(:entry_id))
      elsif params[:read] == true
        options[:not_ids].push(user.unread_entries.pluck(:entry_id))
      end

      if params[:starred] == true
        options[:ids].push(user.starred_entries.pluck(:entry_id))
      elsif params[:starred] == false
        options[:not_ids].push(user.starred_entries.pluck(:entry_id))
      end

      if params[:feed_ids].present?
        subscribed_ids = user.subscriptions.pluck(:feed_id)
        requested_ids = params[:feed_ids]
        options[:feed_ids] = (requested_ids & subscribed_ids)
      elsif params[:tag_id].present?
        options[:feed_ids] = user.taggings.where(tag_id: params[:tag_id]).pluck(:feed_id)
      else
        options[:feed_ids] = user.subscriptions.pluck(:feed_id)
        options[:starred_ids] = user.starred_entries.pluck(:entry_id)
      end

      if options[:ids].present?
        options[:ids] = options[:ids].inject(:&)
      end

      if options[:not_ids].present?
        options[:not_ids] = options[:not_ids].flatten.uniq
      end

      query = build_query(options)


      Entry.search(query).page(params[:page]).records(includes: :feed)
    end

    def self.build_query(options)
      Hash.new.tap do |hash|
        hash[:fields] = ["id"]
        if options[:sort]
          if %w{desc asc}.include?(options[:sort])
            hash[:sort] = [{published: options[:sort]}]
          end
        else
          hash[:sort] = [{published: "desc"}]
        end
        hash[:query] = {
          bool: {
            filter: {
              bool: {
                should: [
                  {terms: {feed_id: options[:feed_ids]}},
                  {terms: {id: options[:starred_ids]}}
                ]
              }
            }
          }
        }
        if options[:query].present?
          hash[:query][:bool][:must] = {
            query_string: {
              query: options[:query],
              default_operator: "AND"
            }
          }
        end
        if options[:ids].present?
          hash[:query][:bool][:filter][:bool][:must] = {
            terms: {id: options[:ids]}
          }
        end
        if options[:not_ids].present?
          hash[:query][:bool][:filter][:bool][:must_not] = {
            terms: {id: options[:not_ids]}
          }
        end
      end
    end

    def self.build_search(params)
      unread_regex = /(?<=\s|^)is:\s*unread(?=\s|$)/
      read_regex = /(?<=\s|^)is:\s*read(?=\s|$)/
      starred_regex = /(?<=\s|^)is:\s*starred(?=\s|$)/
      unstarred_regex = /(?<=\s|^)is:\s*unstarred(?=\s|$)/
      sort_regex = /(?<=\s|^)sort:\s*(asc|desc|relevance)(?=\s|$)/i
      tag_id_regex = /(?<=\s|^)tag_id:\s*([0-9]+)(?=\s|$)/

      if params[:query].respond_to?(:gsub)
        params[:query] = params[:query].gsub("body:", "content:")
      end

      if params[:query] =~ unread_regex
        params[:query] = params[:query].gsub(unread_regex, '')
        params[:read] = false
      elsif params[:query] =~ read_regex
        params[:query] = params[:query].gsub(read_regex, '')
        params[:read] = true
      end

      if params[:query] =~ starred_regex
        params[:query] = params[:query].gsub(starred_regex, '')
        params[:starred] = true
      elsif params[:query] =~ unstarred_regex
        params[:query] = params[:query].gsub(unstarred_regex, '')
        params[:starred] = false
      end

      if params[:query] =~ sort_regex
        params[:sort] = params[:query].match(sort_regex)[1].downcase
        params[:query] = params[:query].gsub(sort_regex, '')
      end

      if params[:query] =~ tag_id_regex
        params[:tag_id] = params[:query].match(tag_id_regex)[1].downcase
        params[:query] = params[:query].gsub(tag_id_regex, '')
      end

      params[:query] = escape_search(params[:query])

      params
    end

    def self.escape_search(query)
      if query.present? && query.respond_to?(:gsub)
        special_characters_regex = /([\+\-\!\{\}\[\]\^\~\?\\])/
        escape = '\ '.sub(' ', '')
        query = query.gsub(special_characters_regex) { |character| escape + character }

        colon_regex = /(?<!title|feed_id|content|author):(?=.*)/
        query = query.gsub(colon_regex, '\:')
        query
      end
    end

  end
end