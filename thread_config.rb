require 'active_record'
require 'uri'
require './markdown_utils'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: 'localhost', # e.g., 'example.com'
  port: 5432, # Default PostgreSQL port
  database: 'r_anime',
  username: 'postgres',
)

class Comment < ActiveRecord::Base
  self.table_name = 'comments' # Make sure this matches your table name

  def readonly?
    true
  end
end

class Post < ActiveRecord::Base
  self.table_name = 'posts' # Make sure this matches your table name

  def readonly?
    true
  end
end

class User < ActiveRecord::Base
  self.table_name = 'users' # Make sure this matches your table name

  def readonly?
    true
  end
end

class ThreadConfig
  JSON_EXT = '.json'
  include MarkdownUtils

  attr_accessor :keyword, :header, :funcs

  def initialize(keyword:, header:, func_names:)
    @keyword = keyword.downcase
    @header = header
    invalid_func_names = func_names.reject { |func_name| respond_to?(func_name) }
    if !invalid_func_names.empty?
      raise "function names #{invalid_func_names} are not defined"
    end
    @funcs = func_names.map { |name| method(name) }
  end

  def nomination_author(comments = nil)
    return "Nominated by" if comments.nil?
    comments.map do |comment|
      'u/' + comment['data']['author']
    end
  end

  def thread_link(comments = nil)
    return "Thread/Link" if comments.nil?

    comments.map do |comment|
      comment_text = comment['data']['body']
      links = extract_links(comment_text).map { |link| link[:url] }.map do |url|
        url.sub(/\w+\.reddit/, 'www.reddit')
      end.map.with_index do |url, i|
        "[TODO #{i + 1}](#{url})"
      end
      if links.empty?
        next "LINKS NOT FOUND"
      end
      if links.size != 1
        next links.join(', ')
      end
      links[0].sub('TODO 1', 'TODO')
    end
  end

  def examples(comments = nil)
    return "Example(s)" if comments.nil?
    thread_link(comments)
  end

  def author(comments = nil)
    return "User" if comments.nil?

    batched_authors = comments.map do |comment|
      comment['data']['body'].scan(/\bu\/([\w\d\-_]+)/i).flatten.map(&:downcase).uniq
    end
    authors_to_lookup = batched_authors.flatten.to_set

    user_map = look_up_users(authors_to_lookup)

    batched_authors.map do |authors|
      authors.map { |author| user_map[author] }.join(', ')
    end
  end

  def date_comments(comments = nil)
    return "Date" if comments.nil?

    batched_links = comments.map do |comment|
      comment_text = comment['data']['body']
      extract_links(comment_text).map { |link| link[:url] }.map do |url|
        URI.parse(url).path.split('/')[-1]
      end.reject { |slug| slug.size > 7 }
    end

    map = Comment.where(id36: batched_links.flatten).pluck(:id36, :created_time).to_h

    batched_links.map do |links|
      if links.empty?
        next "COMMENT NOT FOUND"
      end
      links.map do |link|
        map[link]&.to_date
      end.join(', ')
    end
  end

  # TODO a specific version for rewatches to look up in the wiki too
  def date_posts(comments = nil)
    return "Date" if comments.nil?

    batched_links = comments.map do |comment|
      comment_text = comment['data']['body']
      extract_links(comment_text).map { |link| link[:url] }.map do |url|
        URI.parse(url).path.split('/')[-2]
      end.reject { |slug| slug.size > 7 }
    end

    map = Post.where(id36: batched_links.flatten).pluck(:id36, :created_time).to_h

    batched_links.map do |links|
      if links.empty?
        next "POST NOT FOUND"
      end
      links.map do |link|
        map[link]&.to_date
      end.join(', ')
    end
  end

  def date(comments = nil)
    return "Date" if comments.nil?

    batched_links = comments.map do |comment|
      comment_text = comment['data']['body']
      extract_links(comment_text).map { |link| link[:url] }.map do |url|
        URI.parse(url).path.split('/').reverse.find { |slug| slug.size <= 7 }
      end
    end

    map = (Comment.where(id36: batched_links.flatten).pluck(:id36, :created_time) +
          Post.where(id36: batched_links.flatten).pluck(:id36, :created_time)
    ).to_h

    batched_links.map do |links|
      if links.empty?
        next "POST/COMMENT NOT FOUND"
      end
      links.map do |link|
        map[link]&.to_date
      end.join(', ')
    end
  end

  def reason(comments = nil)
    return "Reason" if comments.nil?
    comments.map {|_comment| 'TODO'}
  end

  def why(comments = nil)
    return "Why" if comments.nil?
    comments.map {|_comment| 'TODO'}
  end

  def look_up_users(usernames)
    User.where('lower(username) IN (?)', usernames).pluck(:username).map { |username| [username.downcase, 'u/' + username] }.to_h
  end
end
