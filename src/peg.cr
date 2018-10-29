class ParseResult
    property success : Bool
    property byte_end : Int32
    property parsed : String?

    def initialize(@success, @byte_end = 0, @parsed = nil)
    end

    def to_s(io)
        io << (success ? "Success: '#{@parsed}'" : "Failure")
    end
end

class Parser
    property block : String -> ParseResult

    def initialize(@block)
    end

    def parse(string : String) : ParseResult
        block.call(string)
    end
end

macro parser_expr(ast)
    {% if ast.class_name == "RegexLiteral" %}
        Parser.new ->(str : String) {
            md = {{ ast }}.match(str)
            puts "asdasda"
            puts md ? md.byte_end : -1
            puts "asdasd"
            if md && md.begin == 0
                ParseResult.new(true, md.byte_end, md[0])
            else
                ParseResult.new(false)
            end
        }
    {% elsif ast.class_name == "Call" %}
        {% if ast.name == "|" %}
            Parser.new ->(str : String) {
                pr = parser_expr({{ ast.receiver }}).parse(str)
                if pr.success
                    pr
                else
                    parser_expr({{ ast.args[0] }}).parse(str)
                end
            }
        {% elsif ast.name == ">>" %}
            Parser.new ->(str : String) {
                pr = parser_expr({{ ast.receiver }}).parse(str)
                if pr.success
                    next_pr = parser_expr({{ ast.args[0] }}).parse(str[pr.byte_end..-1])
                    if next_pr.success
                        ParseResult.new(true, next_pr.byte_end, str[0...pr.byte_end + next_pr.byte_end])
                    else
                        next_pr
                    end
                else
                    pr
                end
            }
        {% end %}
    {% elsif ast.class_name == "Expressions" %}
        parser_expr({{ ast.expressions[0] }})
    {% end %}
end

macro parser(ast)
    {{ puts ast.class_name }}
    {% if ast.class_name == "NamedTupleLiteral" %}
        Parser.new ->(str : String) {
            rules = Hash(String, (String -> ParseResult)).new
            {% for key, value in ast %}
                rules["{{ key.id }}"] = ->(str : String) {
                    parser_expr({{ value }}).parse(str)
                }
            {% end %}
            rules["main"].call(str)
        }
    {% end %}
end
