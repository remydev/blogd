require "kemal"
require "html_builder"

class Model
	class Article
		property title    : String
		property subtitle : String?
		property content  : String
		property author   : String?

		getter comments   : Array(Nil)

		JSON.mapping({
			title:       String,
			subtitle:    String?,
			content:     String,
			author:      String?,
			comments:    Array(Nil)
		})

		def initialize(@title, @content, @subtitle = nil, @author = nil)
			@comments = Array(Nil).new
		end

		def to_html
			HTML.build {
				div class: "hero is-info is-bold blog-picture" {
					div class: "hero-body" {
					}
				}
				div(class: "section blog-item") {
					div(class: "container") {
						article class: "card article" {
							div class: "card-content" {
								div class: "media" {
									div class: "media-content has-text-centered" {
										a href: "/blog/" + @title {
											h2 class: "title is-1" {
												text @title
											}

											@subtitle.try { |subtitle|
												h3 class: "subtitle is-2" {
													text subtitle
												}
											}
										}

										@author.try { |author|
											text author
										}
									}
								}

								div class: "content article-body" {
									html @content
								}
							}
						}
						br # Remove as soon as proper CSS is in place.
					}
				}
			}
		end
	end

	def self.articles
		array = Array(Article).new
		Dir.each_child "storage" do |filename|
			unless filename.match /\.json$/
				next
			end

			array << Article.from_json File.read "storage/#{filename}"
		end
		array
	end
end

get "/articles" do
	{
		articles: [
			Model.articles.to_json
		]
	}.to_json
end

get "/" do |env|
	env.response.headers["X-Title"] = "Blog"

	articles = Model.articles

	HTML.build {
		if articles.empty?
			section class: "section" {
				div class: "container" {
					p class: "title is-2 has-text-centered" {
						text "No content here!"
					}
					p class: "subtitle is-2 has-text-centered" {
						text "Maybe something will be posted in the future!"
					}
				}
			}
		else
			html articles.each { |x| html x.to_html }
		end
	}
end

get "/:id" do |env|
	article = Model.articles.find{ |x| x.title == env.params.url["id"] }

	if article.nil?
		halt env, status_code: 404
	end

	env.response.headers["X-Title"] = article.title

	HTML.build {
		html article.to_html
	}
end

Kemal.run

