require "ipc"
require "json"
require "yaml"
require "markdown"
require "html_builder"
require "./blogd.cr"

class BlogD
	class Article
		def to_html(**attrs)
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
									if attrs[:short]?
										html @content[0..100] + "..."
									else
										html @content
									end
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
			p filename
			unless filename.match /\.md$/
				next
			end
			p filename


			begin
				array << Article.from_markdown_file "storage/#{filename}"
			rescue
			end
		end
		array
	end
end

IPC::Service.new("blogd").loop do |event|
	client = event.client

	if event.is_a? IPC::Event::Message
		message = event.message

		case message.type
		when BlogD::RequestTypes::GET_ALL_ARTICLES.value
			resources_requested = false
			article = nil

			client.send BlogD::ResponseTypes::OK.value.to_u8, {
				articles: BlogD.articles
			}.to_json
		when BlogD::RequestTypes::GET_ARTICLE.value
			title = message.payload

			article = BlogD.articles.find { |x| x.title == title }

			if article
				client.send BlogD::ResponseTypes::OK.value.to_u8, {
					article: article
				}.to_json
			else
				client.send BlogD::ResponseTypes::ARTICLE_NOT_FOUND.to_u8, ""
			end

			next
		end

		client.send BlogD::ResponseTypes::INVALID_REQUEST.to_u8, "type field has an unknown value"
		next
	end
end

