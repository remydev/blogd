require "ipc"
require "html_builder"

class BlogD
	enum RequestTypes
		GET_ALL_ARTICLES
		GET_ARTICLE
	end

	enum ResponseTypes
		OK
		INVALID_REQUEST
		ARTICLE_NOT_FOUND
	end
end

class BlogD::Request
	JSON.mapping({
		action: String?, # Nil in common cases.
		resource: Array(String),
		format: String?
	})
end

class BlogD::Article
	property title    : String
	property subtitle : String?
	property content  : String
	property author   : String?
	property body     : String
	property html_body : String

	getter comments   : Array(Nil)

	JSON.mapping({
		title:       String,
		subtitle:    String?,
		content:     String,
		author:      String?,
		comments:    Array(Nil),
		body:        String,
		html_body:   String
	})

	def initialize(@title, @content, @subtitle = nil, @author = nil, @body = "", @html_body = "")
		@comments = Array(Nil).new
	end

	def self.from_markdown_file(filename)
		json_filename = filename.gsub /\.md$/, ".json"
		article = nil

		up_to_date = File.exists?(json_filename) &&
			File.info(filename).modification_time < File.info(json_filename).modification_time

		# FIXME: Bad code. REWRITE. IT. ALL.
		unless up_to_date
			puts "!! ARTICLE NOT UP TO DATE, REBUILDING !! #{filename}"

			content = File.read filename

			header_end = content.match(/\.\.\.\n?/).try &.byte_end

			headers = nil
			body = nil

			unless header_end
				body = content
			else
				headers = YAML.parse content[4...header_end-4]
				# FIXME: Generate the short version too. D:
				body = content[header_end..content.bytesize]

				p headers
				p body
			end

			html_body = Markdown.to_html body

			article = BlogD::Article.new(
				(headers.try &.["title"]?.try &.as_s? || ""),
				body,
				headers.try &.["subtitle"]?.try &.as_s?,
				headers.try &.["author"]?.try &.as_s?,
				body: body || "",
				html_body: html_body || ""
			)

			File.write json_filename, article.to_json
		else
			article = BlogD::Article.from_json File.read json_filename
		end

		article
	end
end

class BlogD::GetAllArticlesResponse
	JSON.mapping({
		articles: Array(Article)
	})
end
class BlogD::GetArticleResponse
	JSON.mapping({
		article: Article
	})
end


class BlogD::Client < IPC::Client
	def get_all_articles
		send BlogD::RequestTypes::GET_ALL_ARTICLES.value.to_u8, ""
		BlogD::GetAllArticlesResponse.from_json read.payload
	end

	def get_article(title : String)
		send BlogD::RequestTypes::GET_ARTICLE.value, title

		response = read

		p response

		if response.type == BlogD::ResponseTypes::ARTICLE_NOT_FOUND.value
			return nil
		end

		BlogD::GetArticleResponse.from_json response.payload
	end
end

