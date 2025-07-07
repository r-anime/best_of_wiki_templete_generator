require 'httparty'
require 'commonmarker'
require './markdown_utils'
require './thread_config'

require 'json' # debug

include MarkdownUtils

COMMENT_CONFIG = ThreadConfig.new(keyword: 'comment', header: "Best Comment", func_names: [:thread_link, :author, :date_comments, :nomination_author])
REWATCH_CONFIG = ThreadConfig.new(keyword: 'rewatch', header: "Most Enjoyable Rewatch", func_names: [:thread_link, :reason, :author, :date_posts, :nomination_author])
CONTRIBUTOR_CONFIG = ThreadConfig.new(keyword: 'contributor', header: "Most Valuable Contributor", func_names: [:author, :nomination_author, :why])
CONTENT_CONFIG = ThreadConfig.new(keyword: 'content', header: "Best Original Content", func_names: [:thread_link, :author, :date_posts, :nomination_author])
ESSAY_CONFIG = ThreadConfig.new(keyword: 'essay', header: "Best Original Essay", func_names: [:thread_link, :author, :date, :nomination_author])
REVIEW_CONFIG = ThreadConfig.new(keyword: 'review', header: "Best Original Review", func_names: [:thread_link, :author, :date, :nomination_author])
CONFIG = {
  year: 2023,
  index_url: 'https://www.reddit.com/r/anime/comments/194zy9q/best_of_ranime_2023_edition_index/',
  # year: 2024,
  # index_url: 'https://www.reddit.com/r/anime/comments/1hubixk/best_of_ranime_2024_edition_index/',
  categories: {
    comment: COMMENT_CONFIG,
    rewatch: REWATCH_CONFIG,
    # fanart: ThreadConfig.new(keyword: 'fanart', header: "Best Comment", func_names: [:thread_link, :author, :date, :nomination_author]),
    # art: ThreadConfig.new(keyword: 'non-art', header: "Best Comment", func_names: [:thread_link, :author, :date, :nomination_author]),
    contributor: CONTRIBUTOR_CONFIG,
    content: CONTENT_CONFIG,
    essay: ESSAY_CONFIG,
    review: REVIEW_CONFIG,
  }
}
JSON_EXT = '.json'

def main(year, index_url, categories)
  nomination_links = fetch_individual_nomination_threads(year, index_url, categories)
  # puts "nomination_links:"
  # nomination_links.each do |link|
  #   puts link.inspect
  # end

  markdown = nomination_links.map do |link|
    process_nomination_thread(link)
  end.join("\n\n---\n\n")

  puts "markdown: \n#{markdown}"

end

def fetch_individual_nomination_threads(year, index_url, categories)
  index_json = fetch_reddit_post(index_url + JSON_EXT)
  # index_json = JSON.parse(File.read('./index.json'))
  post = index_json[0]["data"]["children"][0]["data"]
  if !post["title"].include?(year.to_s) || !post["title"].downcase.include?('index')
    raise "This doesn't look like the correct index url for the year #{year}"
  end

  body_text = post["selftext"]

  extract_links(body_text).select do |link|
    link[:url].match?(/http.?:\/\/(\w+\.)?redd/)
  end.select do |link|
    category = categories.values.find { |category| link[:text].downcase.include?(category.keyword) }
    next false if category.nil?
    link[:category] = category
    true
  end
end

def process_nomination_thread(link)
  # puts "link: #{link.inspect}"
  nomination_json = fetch_reddit_post(link[:url] + JSON_EXT)
  funcs = link[:category].funcs

  markdown = "####{link[:category].header}\n\n"

  markdown += funcs.map { |func| func.call() }.join(' | ')
  markdown += "\n"
  markdown += funcs.map { |func| '---' }.join('|')
  markdown += "\n"

  comments = nomination_json[1]['data']['children']

  batched_comments = funcs.map do |func|
    func.call(comments)
  end
  # puts "\n\nbatched_comments: #{batched_comments}"

  batched_comments = batched_comments.transpose

  markdown += batched_comments.map { |arr| arr.join(' | ') }.join("\n")
  markdown
end

def fetch_reddit_post(url)
  return HTTParty.get(url).parsed_response if !url.include?('redd.it')
  resp = HTTParty.get(url, follow_redirects: false)
  if !resp.code.between?(300, 399)
    raise "expected 3XX for #{url}, but got #{resp.code}: body: #{resp.body}"
  end
  HTTParty.get(resp.headers['location'] + JSON_EXT).parsed_response
end

start = Time.now
main(CONFIG[:year], CONFIG[:index_url], CONFIG[:categories])
puts "Took #{Time.now - start} seconds"
print "\a"

