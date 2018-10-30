class ParseResult
    property success : Bool
    property label : Symbol?
    property children : Set(ParseResult)
    property byte_end : Int32
    property parsed : String

    def initialize(@success, @children = Set(ParseResult).new, @byte_end = 0, @parsed = "")
    end

    def var(sym : Symbol) : ParseResult
        if @label == sym
            self
        else
            elem = @children.find { |e|
                e.var(sym)
            }
            if elem
                elem.var(sym)
            else
                raise "Could not find var #{sym}."
            end
        end
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
                ParseResult.new(true, Set(ParseResult).new, %md.byte_end, %md[0])
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
                        ParseResult.new(true, Set { %pr, %next_pr }, %pr.byte_end + %next_pr.byte_end, %str[0...%pr.byte_end + %next_pr.byte_end])
                    else
                        %next_pr
                    end
                else
                    %pr
                end
            }
        {% elsif ast.name == "rep" %}
            Parser.new ->(%str : String) {
                %ch = Set(ParseResult).new
                %string = String.build { |%string|
                    %pr : ParseResult
                    loop do
                        %pr = parser_expr({{ ast.receiver }}).parse(%str)
                        break unless %pr.success
                        %ch.add(%pr)
                        %string << %pr.parsed
                        %str = %str[%pr.byte_end..-1]
                    end
                }
                ParseResult.new(true, %ch, %string.size(), %string)
            }
        {% elsif ast.name == "maybe" %}
            Parser.new ->(%str : String) {
                %pr = parser_expr({{ ast.receiver }}).parse(%str)
                if %pr.success
                    %pr
                else
                    ParseResult.new(true, Set(ParseResult).new, 0, "")
                end
            }
        {% elsif ast.name == "on" %}
            Parser.new ->(%str : String) {
                %pr = parser_expr({{ ast.receiver }}).parse(%str)
                if %pr.success
                    {% if ast.args.size == 1 %}
                        {{ ast.args[0] }}(%pr)
                    {% else %}
                        ->({{ ast.block.args[0] }} : ParseResult) { {{ ast.block.body }} }.call(%pr)
                    {% end %}
                end
                %pr
            }
        {% elsif ast.name == "let" %}
            Parser.new ->(%str : String) {
                %pr = parser_expr({{ ast.receiver }}).parse(%str)
                %pr.label = {{ ast.args[0] }}
                %pr
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
        Parser.new ->(%str : String) {
            rules = Hash(String, Parser).new
            {% for key, value in ast %}
                rules["{{ key.id }}"] = Parser.new ->(%str : String) {
                    parser_expr({{ value }}).parse(%str)
                }
            {% end %}
            rules["main"].parse(%str)
        }
    {% end %}
end
