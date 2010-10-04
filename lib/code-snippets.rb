#!/usr/bin/ruby

# file: code-snippets.rb

require 'dynarex-usersblog'
require 'nokogiri'
require 'time'
require 'syntax/convertors/html'

class CodeSnippets
  include REXML

  def initialize(opt={})
    @h = opt[:config]
    load()
  end

  def page(n='1', current_user='guest')   
    html_page n, current_user
  end
  
  def tag(tag, n='1', current_user='guest')
    html_tag tag, n, current_user
  end
  
  def user(user, n='1', current_user='guest')
    html_user(user, n, current_user)
  end

  def user_tag(user, tag, n='1', current_user='guest')
    html_user_tag(user, tag, n, current_user)
  end
  
  def rss()
    rss_cached('1') { @blog.page(1) }
  end
  
  def rss_tag(tag)
    rss_cached(tag) { @blog.tag(tag).page(1) }
  end  
  
  def rss_user(user)
    rss_cached(user) { @blog.user(user).page(1) }
  end
  
  def rss_user_tag(user, tag)
    rss_cached(user+tag) { @blog.user(user).tag(tag).page(1) }
  end    
  
  def show(id, current_user='guest')
    
    doc = Document.new('<result><summary/><records/></result>')            
    entry = @blog.entry(id).dup
    doc.root.elements['records'].add entry

    (tags = " [%s]" % entry.text('tags').split(/\s/).join('] [')) if entry.text('tags')
    doc.root.elements['summary'].add Element.new('title').add_text(entry.text('title').to_s + tags)    
    prepare_doc doc
    
    render_html(doc, @xsl_doc_single, current_user).to_s
  end
  
  def reload_renderer()
    load_renderer()
  end
  
  def update(id ,h)
    cache_reset
    # fetch the user
    user = h[:user]
    h.delete :user
    @blog.update_user(user, id, h)
  end
  
  # -- xml interface ------------
  
  def raw_show(id)    
    @blog.entry(id).to_s
  end  
  
  def create_entry(h)
    cache_reset
    user = h[:user]
    @blog.create_entry(h, user)    
  end
  
  def delete(id)
    cache_reset
    @blog.delete(id)
    "record deleted"
  end

  def raw_page(n='1')
    @blog.page n.to_i
  end
  
  private
    
  def html_page(n, current_user='guest')
    @args = [n]
    summary = {title: 'Snippets'}
    html_cached(context=@args, summary, current_user) { @blog.page(n.to_i) }
  end
  
  def html_tag(tag, pg_n, current_user='guest')   
    @args = [tag, pg_n]
    summary = {title: tag + ' code', tag: tag}  
    html_cached(context=@args, summary, current_user) { @blog.tag(tag).page(pg_n.to_i) }
  end  
  
  def html_user(user, pg_n, current_user='guest')
    @args = ['user', user, pg_n]
    summary = {title: 'Snippets', user: user}
    html_cached(context=@args, summary, current_user) { @blog.user(user).page(pg_n.to_i) }
  end
  
  def html_user_tag(user, tag, pg_n, current_user='guest')  
    @args = ['user', user, 'tag', tag, pg_n]
    summary = {title: 'Snippets', user: user, tag: tag}
    html_cached(context=@args, summary, current_user) { @blog.user(user).tag(tag).page(pg_n.to_i) }
  end

  def html_cached(context, summary, current_user='guest', &b)
    c = context.join
    @page_cache.read(c + current_user) do 
      view_html(@doc_cache.read(c + current_user){b.call}, c, summary, current_user).to_s
    end
  end

  def view_html(raw_doc, context, summary, current_user='guest')
    
    blk = lambda do
      page_doc = Document.new(raw_doc.to_s)  

      prepare_doc(page_doc)  
      total_records, total_pages, page_number = %w(total_records total_pages page_number)\
          .map {|x| page_doc.root.text('summary/' + x).to_s.to_i}
      
      k = page_number * 10      
      pages = "%d-%d" % [k-9, total_records >= k ? k : total_records]

      summary[:pages] = pages
      summary[:prev_page] = page_number - 1  if page_number > 1
      summary[:next_page] = page_number + 1  if page_number < total_pages
      
      @args.pop if @args.length > 0 and @args[-1][/^\d+$/]  
      summary[:rss_url] = (@args.unshift '/rss').join('/')
      
      summary.each do |name, text|
        page_doc.root.elements['summary'].add Element.new(name.to_s).add_text(text.to_s)  
      end
      
      summary_node = XPath.first(page_doc.root, 'summary')
      tags = Document.new(@tags.to_s).root.elements['records']
      tags.name = 'tags'
      summary_node.add tags
      latest_posts = Document.new(@latest_posts.to_s).root.elements['records']
      latest_posts.name = 'latest_posts'
      summary_node.add latest_posts
      bottom_summary = summary_node.dup
      bottom_summary.name = 'bottom_summary'
      page_doc.root.add bottom_summary
      page_doc
    end
    
    xml_doc =  context != '1' ? @hc_xml.read(context+current_user, &blk) : blk.call
    
    render_html(xml_doc, @xsl_doc, current_user)

  end


  def prepare_doc(page_doc)
    page_doc.root.name = 'snippets'
    convertor = Syntax::Convertors::HTML.for_syntax "ruby"

    XPath.each(page_doc.root,'records/entry') do |entry|

      line = entry.elements['body/text()'].to_s.gsub('&amp;','&#38;')
      buffer = line.gsub(/&lt;(\/?)(code|pre|span|br|a\s|\/a)(\/?[^&]+)?&gt;/,'<\1\2\3>').gsub('&#38;','&amp;')

      doc_body = Document.new("<div class='post-body'>%s</div>" % buffer)

      XPath.each(doc_body.root, 'code') do |code| 
        styled_code = code.text.to_s[/<span>/] ? code.text.to_s : convertor.convert(REXML::Text::unnormalize(code.text.to_s))
        code.add Document.new("%s" % styled_code).root
        code.text = ''
        code.name = '_code'
      end

      body = entry.elements['body']
      body.parent.delete body
      entry.add Document.new(doc_body.to_s.gsub(/<\/?_code>/,'')).root

      tags = entry.elements['tags']
      tags.text.to_s.split(/\s/).map {|x| tags.add Element.new('tag').add_text(x)}
      tags.text = ''

      entry.add_attribute('created',Time.parse(entry.attribute('created').value).strftime("%b %d, %Y"))

    end

  end

  def load()
    @blog = DynarexUsersBlog.new(@h[:filepath], @h[:default_user])            
    @tags = sidetags(@blog.tags)
    @latest_posts = latest_posts(@blog)
    @page_cache = HashCache.new
    @doc_cache = HashCache.new
    @hc_xml = HashCache.new(file_cache: true)
    @rss_cache = HashCache.new
    @args = []
    load_renderer()
  end

  def sidetags(all_tags)

    tags = all_tags.sort_by {|name,count| -count.to_i}[0..49]
    biggest_tag = tags.first[1].to_i
    abc_tags = tags.sort_by &:first

    dynarex = Dynarex.new('tags/tag(name,gauge,count)')
    abc_tags.each do |word, word_size|
      weight = 100 / (biggest_tag / word_size.to_i)
      gauge = (weight / 10).to_i
      gauge = 8 if gauge > 8
      dynarex.create name: word, gauge: gauge, count: word_size
    end

    dynarex.to_xml
  end

  def latest_posts(blog)
    posts = Polyrex.new('latest_posts/posts[title]/entry[title,id]')

    %w(ruby javascript html xml array shell linux bash).each do |x|
      posts.create.posts(title: x) do |create|
        XPath.each(blog.tag(x).page(1).root, "records/entry[position() < 4]") do |entry|
          create.entry title: entry.text('title').to_s, id: entry.attribute('id').value.to_s
        end
      end
    end

    posts.to_xml
  end

  def load_renderer()

    xsl = @h[:xsl]
    urls = [xsl[:outer], xsl[:page], xsl[:entry], xsl[:rss]]

    main, snippets, snippets_entry, @xsl_rssdoc = urls.map do |url|
      Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
    end
    
    @xsl_doc = Document.new(main.to_s)
    XPath.each(snippets.root, 'xsl:template') {|template|  @xsl_doc.root.add template }

    @xsl_doc_single = Document.new(main.to_s)
    XPath.each(snippets_entry.root, 'xsl:template') {|template|  @xsl_doc_single.root.add template }

  end
  
  def render_html(xml_doc, xsl_doc, current_user='guest')
    xsl_params = ['current_user', current_user]
    Nokogiri::XSLT(xsl_doc.to_s).transform(Nokogiri::XML(xml_doc.to_s), Nokogiri::XSLT.quote_params(xsl_params))     
  end
  
  alias render_rss render_html  

  def rss_cached(context, &b)
    @rss_cache.read(context) do 
      view_rss(@doc_cache.read(context){b.call})
    end
  end

  def view_rss(doc)
    page_doc = Document.new(doc.to_s)
    rss_doc = Document.new(render_rss(page_doc,@xsl_rssdoc).to_s)
    
    XPath.each(rss_doc.root,'channel/item/description') do |desc|
      desc.text = desc.text.to_s.gsub(/\n/,'\0<br />')
    end
    rss_doc.to_s
  end
  
  def cache_reset()
    @page_cache.reset
    @doc_cache.reset
    @hc_xml.reset
  end
        
end
