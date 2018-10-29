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
        Parser.new ->(%str : String) {
            %md = {{ ast }}.match(%str)
            if %md && %md.begin == 0
                ParseResult.new(true, %md.byte_end, %md[0])
            else
                ParseResult.new(false)
            end
        }
    {% elsif ast.class_name == "Call" %}
        {% if ast.name == "|" %}
            Parser.new ->(%str : String) {
                %pr = parser_expr({{ ast.receiver }}).parse(%str)
                if %pr.success
                    %pr
                else
                    parser_expr({{ ast.args[0] }}).parse(%str)
                end
            }
        {% elsif ast.name == ">>" %}
            Parser.new ->(%str : String) {
                %pr = parser_expr({{ ast.receiver }}).parse(%str)
                if %pr.success
                    %next_pr = parser_expr({{ ast.args[0] }}).parse(%str[%pr.byte_end..-1])
                    if %next_pr.success
                        ParseResult.new(true, %pr.byte_end + %next_pr.byte_end, %str[0...%pr.byte_end + %next_pr.byte_end])
                    else
                        %next_pr
                    end
                else
                    %pr
                end
            }
        {% elsif ast.name == "rep" %}
            Parser.new ->(%str : String) {
                %string = String.build { |%string|
                    %pr : ParseResult
                    loop do
                        %pr = parser_expr({{ ast.receiver }}).parse(%str)
                        break unless %pr.success
                        %string << %pr.parsed
                        %str = %str[%pr.byte_end..-1]
                    end
                }
                ParseResult.new(true, %string.size(), %string)
            }
        {% end %}
    {% elsif ast.class_name == "SymbolLiteral" %}
        rules["{{ ast.id }}"]
    {% elsif ast.class_name == "Expressions" %}
        parser_expr({{ ast.expressions[0] }})
    {% end %}
end

macro parser(ast)
    {% if ast.class_name == "NamedTupleLiteral" %}
        Parser.new ->(str : String) {
            rules = Hash(String, Parser).new
            {% for key, value in ast %}
                rules["{{ key.id }}"] = Parser.new ->(str : String) {
                    parser_expr({{ value }}).parse(str)
                }
            {% end %}
            rules["main"].parse(str)
        }
    {% end %}
end
