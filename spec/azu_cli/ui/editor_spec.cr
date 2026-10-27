require "../../spec_helper"

private alias Editor = AzuCLI::UI::Editor

describe AzuCLI::UI::Editor do
  it "types, moves and deletes across lines" do
    editor = Editor.new
    editor.insert("ab")
    editor.left
    editor.insert('X')
    editor.text.should eq "aXb"
    editor.end_of_line
    editor.newline
    editor.insert("cd")
    editor.text.should eq "aXb\ncd"
    editor.home
    editor.backspace
    editor.text.should eq "aXbcd"
    editor.row.should eq 0
    editor.kill
    editor.text.should eq "aXb"
  end

  it "indents after a block opener and dedents end" do
    editor = Editor.new
    editor.insert("def titles(n = 3)")
    editor.newline
    editor.insert("Post.all")
    editor.newline
    editor.insert("end")
    editor.text.should eq "def titles(n = 3)\n  Post.all\nend"
  end

  it "knows finished code from code that still has a block, a bracket or a string open" do
    Editor.complete?("1 + 2").should be_true
    Editor.complete?("def titles(n = 3)").should be_false
    Editor.complete?("def titles(n = 3)\n  Post.all\nend").should be_true
    Editor.complete?("def answer = 42").should be_true
    Editor.complete?("Post.all.each do |post|").should be_false
    Editor.complete?("Post.all.each do |post|\n  puts post.title\nend").should be_true
    Editor.complete?("[1,\n2").should be_false
    Editor.complete?("puts \"a # b\"").should be_true
    Editor.complete?("puts \"open").should be_false
    Editor.complete?("x = if true then 1 else 2 end").should be_true
  end
end
