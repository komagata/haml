#!/usr/bin/env ruby

require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/sass'
require 'sass/engine'

class SassEngineTest < Test::Unit::TestCase
  EXCEPTION_MAP = {
    "!a = 1 + " => 'Constant arithmetic error: "1 +"',
    "!a = 1 + 2 +" => 'Constant arithmetic error: "1 + 2 +"',
    "!a = \"b" => 'Unterminated string: "\\"b"',
    "!a = #aaa - a" => 'Undefined operation: "#aaaaaa minus a"',
    "!a = #aaa / a" => 'Undefined operation: "#aaaaaa div a"',
    "!a = #aaa * a" => 'Undefined operation: "#aaaaaa times a"',
    "!a = #aaa % a" => 'Undefined operation: "#aaaaaa mod a"',
    "!a = 1 - a" => 'Undefined operation: "1 minus a"',
    "!a = 1 * a" => 'Undefined operation: "1 times a"',
    "!a = 1 / a" => 'Undefined operation: "1 div a"',
    "!a = 1 % a" => 'Undefined operation: "1 mod a"',
    ":" => 'Invalid attribute: ":"',
    ": a" => 'Invalid attribute: ": a"',
    ":= a" => 'Invalid attribute: ":= a"',
    "a\n  :b" => 'Invalid attribute: ":b "',
    "a\n  :b: c" => 'Invalid attribute: ":b: c"',
    "a\n  :b:c d" => 'Invalid attribute: ":b:c d"',
    "a\n  :b=c d" => 'Invalid attribute: ":b=c d"',
    "a\n  :b c;" => 'Invalid attribute: ":b c;" (This isn\'t CSS!)',
    "a\n  b : c" => 'Invalid attribute: "b : c"',
    "a\n  b=c: d" => 'Invalid attribute: "b=c: d"',
    ":a" => 'Attributes aren\'t allowed at the root of a document.',
    "!" => 'Invalid constant: "!"',
    "!a" => 'Invalid constant: "!a"',
    "! a" => 'Invalid constant: "! a"',
    "!a b" => 'Invalid constant: "!a b"',
    "a\n\t:b c" => "Illegal Indentation: Only two space characters are allowed as tabulation.",
    "a\n :b c" => "Illegal Indentation: Only two space characters are allowed as tabulation.",
    "a\n    :b c" => "Illegal Indentation: Only two space characters are allowed as tabulation.",
    "a\n  :b c\n  !d = 3" => "Constants may only be declared at the root of a document.",
    "!a = 1b + 2c" => "Incompatible units: b and c",
    "& a\n  :b c" => "Base-level rules cannot contain the parent-selector-referencing character '&'",
    "a\n  :b\n    c" => "Illegal nesting: Only attributes may be nested beneath attributes.",
    "a,\n  :b c" => "Rules can\'t end in commas.",
    "!a = b\n  :c d\n" => "Illegal nesting: Nothing may be nested beneath constants.",
    "@import foo.sass" => "File to import not found or unreadable: foo.sass",
    "@import templates/basic\n  foo" => "Illegal nesting: Nothing may be nested beneath import directives.",
    "foo\n  @import templates/basic" => "Import directives may only be used at the root of a document.",
    "!foo = bar baz !" => "Unterminated constant.",
    "!foo = !(foo)" => "Invalid constant.",
  }
  
  def test_basic_render
    renders_correctly "basic", { :style => :compact }
  end

  def test_alternate_styles
    renders_correctly "expanded", { :style => :expanded }
    renders_correctly "compact", { :style => :compact }
    renders_correctly "nested", { :style => :nested }
    renders_correctly "compressed", { :style => :compressed }
  end
  
  def test_exceptions
    EXCEPTION_MAP.each do |key, value|
      begin
        Sass::Engine.new(key).render
      rescue Sass::SyntaxError => err
        assert_equal(value, err.message)
        assert(err.sass_line, "Line: #{key}")
        assert_match(/\(sass\):[0-9]+/, err.backtrace[0], "Line: #{key}")
      else
        assert(false, "Exception not raised for\n#{key}")
      end
    end
  end

  def test_exception_line
    to_render = "rule\n  :attr val\n// comment!\n\n  :broken\n"
    begin
      Sass::Engine.new(to_render).render
    rescue Sass::SyntaxError => err
      assert_equal(5, err.sass_line)
    else
      assert(false, "Exception not raised for '#{to_render}'!")
    end
  end

  def test_imported_exception
    [1, 2].each do |i|
      i = nil if i == 1
      begin
        Sass::Engine.new("@import bork#{i}", :load_paths => [File.dirname(__FILE__) + '/templates/']).render
      rescue Sass::SyntaxError => err
        assert_equal(2, err.sass_line)
        assert_match(/bork#{i}\.sass$/, err.sass_filename)
      else
        assert(false, "Exception not raised for imported template: bork#{i}")
      end
    end
  end

  def test_default_function
    assert_equal("foo {\n  bar: url(foo.png); }\n",
                 render("foo\n  bar = url(foo.png)\n"));
  end

  def test_multiline_selector
    assert_equal("#foo #bar,\n#baz #boom {\n  foo: bar; }\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar"))
    assert_equal("#foo #bar,\n#foo #baz {\n  foo: bar; }\n",
                 render("#foo\n  #bar,\n  #baz\n    :foo bar"))
    assert_equal("#foo #bar, #baz #boom { foo: bar; }\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar", :style => :compact))
                 
    assert_equal("#foo #bar,#baz #boom{foo:bar}\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar", :style => :compressed))
  end

  def test_colon_only
    begin
      render("a\n  b: c", :attribute_syntax => :normal)
    rescue Sass::SyntaxError => e
      assert_equal("Illegal attribute syntax: can't use alternate syntax when :attribute_syntax => :normal is set.",
                   e.message)
    else
      assert(false, "SyntaxError not raised for :attribute_syntax => :normal")
    end

    begin
      render("a\n  :b c", :attribute_syntax => :alternate)
    rescue Sass::SyntaxError => e
      assert_equal("Illegal attribute syntax: can't use normal syntax when :attribute_syntax => :alternate is set.",
                   e.message)
    else
      assert(false, "SyntaxError not raised for :attribute_syntax => :alternate")
    end
  end

  def test_directive
    assert_equal("@a b;", render("@a b"))

    assert_equal("@a {\n  b: c; }\n", render("@a\n  :b c"))
    assert_equal("@a { b: c; }\n", render("@a\n  :b c", :style => :compact))
    assert_equal("@a {\n  b: c;\n}\n", render("@a\n  :b c", :style => :expanded))
    assert_equal("@a{b:c}\n", render("@a\n  :b c", :style => :compressed))

    assert_equal("@a {\n  b: c;\n  d: e; }\n",
                 render("@a\n  :b c\n  :d e"))
    assert_equal("@a { b: c; d: e; }\n",
                 render("@a\n  :b c\n  :d e", :style => :compact))
    assert_equal("@a {\n  b: c;\n  d: e;\n}\n",
                 render("@a\n  :b c\n  :d e", :style => :expanded))
    assert_equal("@a{b:c;d:e}\n",
                 render("@a\n  :b c\n  :d e", :style => :compressed))

    assert_equal("@a {\n  #b {\n    c: d; } }\n",
                 render("@a\n  #b\n    :c d"))
    assert_equal("@a { #b { c: d; } }\n",
                 render("@a\n  #b\n    :c d", :style => :compact))
    assert_equal("@a {\n  #b {\n    c: d;\n  }\n}\n",
                 render("@a\n  #b\n    :c d", :style => :expanded))
    assert_equal("@a{#b{c:d}}\n",
                 render("@a\n  #b\n    :c d", :style => :compressed))

    assert_equal("@a {\n  #b {\n    a: b; }\n    #b #c {\n      d: e; } }\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e"))
    assert_equal("@a { #b { a: b; }\n  #b #c { d: e; } }\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :compact))
    assert_equal("@a {\n  #b {\n    a: b;\n  }\n  #b #c {\n    d: e;\n  }\n}\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :expanded))
    assert_equal("@a{#b{a:b}#b #c{d:e}}\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :compressed))
                 
    assert_equal("@a {\n  #foo,\n  #bar {\n    b: c; } }\n",
                 render("@a\n  #foo, \n  #bar\n    :b c"))
    assert_equal("@a { #foo, #bar { b: c; } }\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :compact))
    assert_equal("@a {\n  #foo,\n  #bar {\n    b: c;\n  }\n}\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :expanded))
    assert_equal("@a{#foo,#bar{b:c}}\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :compressed))

    to_render = <<END
@a
  :b c
  #d
    :e f
  :g h
END
    rendered = <<END
@a { b: c;
  #d { e: f; }
  g: h; }
END
    assert_equal(rendered, render(to_render, :style => :compact))
    
    assert_equal("@a{b:c;#d{e:f}g:h}\n", render(to_render, :style => :compressed))
  end

  def test_empty_first_line
    assert_equal("#a {\n  b: c; }\n", render("#a\n\n  b: c"))
  end

  def test_escaped_rule
    assert_equal(":focus {\n  a: b; }\n", render("\\:focus\n  a: b"))
    assert_equal("a {\n  b: c; }\n  a :focus {\n    d: e; }\n", render("\\a\n  b: c\n  \\:focus\n    d: e"))
  end
  
  private

  def render(sass, options = {})
    Sass::Engine.new(sass, options).render
  end

  def renders_correctly(name, options={})
    sass_file  = load_file(name, "sass")
    css_file   = load_file(name, "css")
    css_result = Sass::Engine.new(sass_file, options).render
    assert_equal css_file, css_result
  end

  def load_file(name, type = "sass")
    @result = ''
    File.new(File.dirname(__FILE__) + "/#{type == 'sass' ? 'templates' : 'results'}/#{name}.#{type}").each_line { |l| @result += l }
    @result
  end
end
