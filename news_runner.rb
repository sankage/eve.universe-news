#!/usr/bin/env ruby

require "httparty"

class NewsRunner
  include HTTParty
  base_uri "https://universe.eveonline.com/api/"

  def initialize
  end

  def process
    article_ids = get_article_ids
    get_missing_articles(article_ids)
  end

  private

  def get_article_ids
    article_ids = []
    response = self.class.get("/articles/?page=1&page_size=50&sort=publication_date&order=desc")
    return article_ids if response.code != 200
    article_ids << JSON.parse(response.body).map { |e| e["id"] }
    pages_count = response.headers["x-pages"].to_i
    if pages_count > 1
      (2..pages_count).each do |page|
        response = self.class.get("/articles/?page=#{page}&page_size=50&sort=publication_date&order=desc")
        next if response.code != 200
        article_ids << JSON.parse(response.body).map { |e| e["id"] }
      end
    end
    article_ids.flatten
  end

  def get_missing_articles(article_ids)
    filenames = Dir.glob("news/*.md")
    existing_article_ids = filenames.map { |fn| File.basename(fn, ".md").split("--").last }
    articles_to_grab = article_ids - existing_article_ids
    articles_to_grab.each do |article_id|
      response = self.class.get("/articles/#{article_id}/")
      next if response.code != 200
      parse_article(JSON.parse(response.body))
    end
  end

  def parse_article(article)
    id = article["id"]
    title = article["title"]
    published = article["publicationDate"]
    link = "https://universe.eveonline.com/new-eden-news/#{article["slug"]}"
    content = article["content"][0]["body"]

    adjusted_publish = published.to_s.gsub(/[-T:Z]/,"")
    File.open("news/#{adjusted_publish}--#{id}.md", "w") do |file|
      file.puts "# #{title}"
      file.puts "Published on #{published} at #{link}"
      file.puts ""
      file.puts content
    end
  end
end

NewsRunner.new.process
