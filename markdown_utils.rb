module MarkdownUtils
  def extract_links(markdown_str)
    links = []

    markdown = Commonmarker.parse(markdown_str)
    stack = [markdown]
    while !stack.empty?
      node = stack.shift
      case node.type
      when :link
        # puts "\n\nnode: #{node.inspect}"
        # next if node.url.start_with?('http')
        next unless node.url.start_with?('http')
        links << {text: node_text(node), url: node.url, title: node.title}
      when :block_quote, :code, :code_block
      else
        node.each do |child|
          stack << child
        end
      end
    end

    links
  end

  def node_text(node)
    case node.type
    when :text
      # node.value
      node.string_content
      # when :smart_quote
      #   "'"
    else
      node.each.map { |child| node_text(child) }.join
    end
  end
end