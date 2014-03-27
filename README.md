# Introducing the Code-snippets gem

    require 'code-snippets'

    h = {
      filepath: '/home/james/snippets', 
      default_user: 'jrobertson',
      xsl: {
        outer: 'http://rscript.rorbuilder.info/s/open/snippets/index.xsl', 
        page: 'http://rscript.rorbuilder.info/s/open/snippets/snippets.xsl', 
        entry: 'http://rscript.rorbuilder.info/s/open/snippets/snippets_entry.xsl', 
        rss: 'http://rscript.rorbuilder.info/s/open/snippets/rss.xsl'
      }
    }

    snippets = CodeSnippets.new({config: h})

    # return the front page
    pg = snippets.page '1'

    # return the front page for tag 'json'
    tag_pg = snippets.tag('json', '1')

    # return the front page for user 'jrobertson'
    user_pg = snippets.user('jrobertson', '1')

    # return the front page for user 'jrobertson' with tag 'json'
    user_tag_pg = snippets.user('jrobertson', 'json','1')

    # return the rss feed for the front page
    rss_pg = snippets.rss</pre>

    
*installation* sudo gem install code-snippets

This gem renders the HTML, and RSS for a dynarex-usersblog system, and it also powers snippets.rorbuilder.info

