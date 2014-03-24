# -*- coding: utf-8 -*-

=begin
仕様：
引数：行数、mail | org

処理：

--h1
★折り返し(、。を考慮) ok
★インデント ok

-- h2
、。と，．の変換
数値の半角化
*の■への変換

-- h3
行末スペースの削除 ok
文末空白行の削除 ok

--h4
報告日出力
遅くなりまして申し訳ございませんでした自動出力
リスト後のbodyを分ける仕様どうしようか。 ok

仕様：
- ハイフンなどより深いインデントなら、文を子供にする ok
  つまり、こんな文 

- org <-> mark <-> html <-> latex <-> original
- 目次生成

** リストの仕様
リストと同じ行の要素は全てリストの子供にしておく(html準拠)

** 段落
厳密日本語なら、文頭空文字
簡易日本語もしくは英語なら、空行で認識

# フォーマットneta
header
footer
---
h*
olist
ulist
comment
link
table
---
newline
underline
emphasis (strong)
italic
---
newline [empty char / empty line]
japanese / english / j + e
---

=end

require './wordChecker.rb'

#! ruby -Ku
# require "kconv"
Encoding.default_external = 'utf-8'
# $KCODE = "UTF-8"                # not work

# constant
ORG_LINE_SPACE = /^\s*/
ORG_LINE_COMMENT = /^#+\s*/
ORG_LINE_ULIST = /^[-\+]\s/     # *もリストに出来る仕様はなし!めんどくさい
ORG_LINE_OLIST = /^\d+[\.\)]\s/
ORG_LINE_HEADER = /^\*+\s/
ORG_LINE_HEADER_STAR = /^\*+/

MARK_OLIST = "1. "
MARK_COMMENT = "# "
MARK_TEXT = "t"
MARK_ROOT = "root"

NULL_TEXT = "null"
LIST_TEXT = "!"
TREE_HEADER = /\Ah\d+\z/
TREE_ULIST = /^[-\+]\s/     # *もリストに出来る仕様はなし!めんどくさい
TREE_OLIST = /^\d+[\.\)]\s/

# htmlは区別したい…
URI_TEXT = /(http:\/|https:\/)[a-zA-Z0-9\.]+/

# ========================================================= # 
# group: file access 
# ========================================================= # 

def write(pathStr, lines) 
  file = open(pathStr, "w")
  lines.each do |line|
    file.write(line)
  end
  file.close
  lines
end

# print String List
def printStrList(strList)
  for i in 0..strList.length-1
    print i.to_s + ":" + strList[i]               # p だと文字化け
    print "\n"
  end
end

# 文頭のスペースを削除
def removeSpace(lines)
  dest = []
  for line in lines
    dest << line.strip
  end
  # print dest
  dest
end

# ========================================================= # 
# group: paragraph tree
# ========================================================= # 
# 木構造の保持とメソッド
class Tree
  attr_accessor :root

  def initialize()
    @root = Node.new(0, 0, NULL_TEXT, MARK_ROOT)
  end

  # root start
  def insertNode(node)
    def insert(loc, node)
      if node.level < loc.level then node # 何もしない
      elsif loc.mark == MARK_TEXT then loc.parent.addChild node
      elsif node.level == loc.level then loc.parent.addChild node # 同レベル
      elsif loc.children.empty? then loc.addChild node            # 子供がいない
      elsif node.level < loc.level then loc.addChild node # 同レベル
      elsif node.level > loc.level
        insert(loc.children.last, node)
      end
    end

    insert(@root, node)
  end

  def removeNode(node)
    def remove_node(loc, node)
      if loc == node 
        loc.parent.removeChild node
        true
      else node.children.each do|child|
          if remove_node(child, node) then break
          end
        end
      end
      true
    end
    remove_node(@root, node)
  end

  # prity print Tree's node, and indentation
  def printTree()
    def pTree(node, i)
      puts node.toString i
      node.children.each do|child|
        pTree(child, i+1)
      end
    end
    pTree(@root, 0)
  end

  def toString()
    def nodeToString(node, i)
      s = (node.toString i)
      node.children.each do|child|
        s += nodeToString(child, i+1)
      end
      s
    end
    nodeToString(@root, 0)
  end

  # file writing paragraph tree
  def writeTree(file)
    file.write toString
  end

  # 木全体を走査する
  def each_node(&block)
    def each_node_local(node, &block)
      if block then block.call(node) end
      node.children.each do|child|
        each_node_local(child, &block)
      end
    end
    each_node_local(@root, &block)
    self
  end

  # 木の特定マークのノードだけを走査する
  def each_mark_node(mark, &block)
    def each_mark_node_local(node, mark, &block)
      if node and node.mark == mark and block then block.call node
      end
      node.children.each do|child|
        each_mark_node_local(child, mark, &block)
      end
    end
    each_mark_node_local(@root, mark, &block)
    self
  end

  def length()
    sum = 0
    each_node do
      |node| sum += 1
    end
    sum
  end

  def size() length end         # もっと良い書き方無いのか?
end

# 章、節などのタイトルと中身を保持
# 規約：parentはroot以外必ず存在
# 木の子供.level > 親.level
# 子供同士のlevelは同じ
# テキストは葉
# 
class Node
  attr_accessor :id, :level, :text, :children, :parent, :mark

  # newする時のparent設定やlevel設定が世界から外れてしまった。注意!
  def initialize(id, level = 0, text = NULL_TEXT, mark = MARK_TEXT, parent = nil)
    @id = id
    @level = level
    @text = text
    @mark = mark
    @parent = parent
    @children = []
  end

  def addChild(child)
    @children << child
    child.parent = self
  end

  def removeChild(child)
    @children.delete child
  end

  def toString(i = 0, max = @text.length)
    if max > @text.length then max = @text.length
    end
    s = " " * i * 2 + "#{@id},#{@level},#{@mark},#{@text[0,max]} "
    if @parent then s += "parent:#{@parent.id},#{@parent.mark} "
    end
    if not @children.empty? 
      s += " children:["
      @children.each do |child|
        # s += "#{child.classend@#{child.id if child != nilend , "
        s += "#{child.id}+#{child.mark},"
      end
      s += "]"
    end
    s += "\n"
  end
end


# ========================================================= # 
# class: FileParser
# ========================================================= # 
class FileParser
  attr_accessor :inFormat, :tree

  def initialize(path, inFormat = nil)
    @inFormat = inFormat  # input format (TODO read fmt file)
    @tree = Tree.new
    genParagraphTree(read(path)) # return @tree
  end

  # ファイルから読み取り
  def read(pathStr) 
    lines = []
    open(pathStr, "r").each do |line| lines << line end.close
    lines
  end


  #     ツリーを構成する
  #    行のインデントレベル(空白数)と前のマークを元にNode.levelを決定する
  #   org-mode用
  def genParagraphTree(lines)
    hlevel = 0                    #  *, **, ...headerllevel
    llevel = 0                   # listllevel
    newSpace = 0                  # number of space(newer)
    lspace = 0                    # list space
    id = 0

    lines.each do |line|
      s = line.scan(ORG_LINE_SPACE)[0]
      newSpace = s != nil ? s.length : 0
      line = line.strip()

      if line =~ ORG_LINE_COMMENT                    # comment
        @tree.insertNode(Node.new(id+=1, hlevel+1, line, MARK_COMMENT))

      elsif line =~ ORG_LINE_ULIST or line =~ ORG_LINE_OLIST
        # unordered list (-, +) and orderd list(1., 2., ..)
        lspace = newSpace
        llevel = lspace / 2
        regexp = line =~ ORG_LINE_ULIST ? ORG_LINE_ULIST : ORG_LINE_OLIST
        mark = line.scan(regexp)[0]
        # mark part
        @tree.insertNode(Node.new(id+=1, hlevel + llevel, mark, mark))
        # text part
        @tree.insertNode(Node.new(id+=1, hlevel+llevel+1, 
            line[mark.length, line.length]))

      elsif line =~ ORG_LINE_HEADER   # header(* ,** ,*** ,...)
        hlevel = line.scan(ORG_LINE_HEADER_STAR)[0].length # number of "*"
        mark = "h" + hlevel.to_s
        # @tree.insertNode(Node.new(id+=1, hlevel, 
        #                           line[mark.length, line.length], mark))
        @tree.insertNode(Node.new(id+=1, hlevel, 
            line[/\s.+$/][1..line.length], mark))
        lspace = 0

      else # text
        level = hlevel + 1
        # list exist
        if 0 < lspace and lspace <= newSpace 
          level = hlevel + llevel + 1
        elsif line.length == 0 
          if 0 < lspace then level = hlevel + llevel + 1
          end
          lspace = 0    # empty line
        end
        @tree.insertNode(Node.new(id+=1, level, line, MARK_TEXT))
      end
    end # each
    return @tree
  end
end


# ========================================================= # 
# class: ParagraphReducer 
# ========================================================= # 
# 複数の文を段落にまとめる (空行もしくは文頭全角スペースを区切りにする)
class ParagraphReducer 
  def initialize(tree)
    @tree = tree
    @id = @tree.size                     # 仮idの設定
  end

  # テキスト属性を持つものだけを集めてリストにする 未使用
  def collectTexts(loc)
    # print "format:#{loc.idend,#{loc.markend,#{loc.text[0..10]end:\n"
    texts = []
    textsList = []
    # テキストが出続けるまでループ
    loc.children.each do |child|
      if child.mark == MARK_TEXT
        texts << child.text
      else
        textsList << texts      # 段落ごとにListを分ける
        texts = []
      end
    end
    textsList << texts
    # print textsList.to_s + "\n"

    textsList
  end

  # 1つの行のリストを1つのパラグラフとして1文字列にまとめる
  def collectParagraphs(textsList)
    paragraphs = []
    textsList.each do |texts|
      if not texts.empty?
        paragraph = ""
        texts.each do |row| paragraph += row.strip end
        # insertEmptyChar paragraph # 空文字の挿入
        paragraphs << paragraph
      end
    end
    paragraphs
  end
  
  # 段落の終わりか?
  # 文章以外のマーク、空行、次の文の文頭が全角空白 => T
  def paragraphEnd?(loc, child, i)
    child.mark != MARK_TEXT or child.text == "" or
      (i < loc.children.length - 1 and loc.children[i + 1].text[0] == "　")
  end


  # 行のリストをパラグラフにする操作をlocの全ての子に対して行う
  def reduceToParagraph(loc)
    # print "format:#{loc.idend,#{loc.markend,#{loc.text[0..10]end:\n"
    # puts loc.children.length
    texts = []
    textsList = []
    textRanges = []
    s = -1

    # テキストが出続けるまでループ
    # テキストのリストを作成 +  テキストの出てきたレンジを記録
    loc.children.each_with_index do |child, i|
      # 文章で、空行、文頭空文字まで段落として認識
      if not paragraphEnd?(loc, child, i)
        # if child.mark == MARK_TEXT
        texts << child.text
        if s == -1 then s = i
        end
      else
        # 貯蓄した行リストをリストに入れる
        if not texts.empty?
          textsList << texts 
          textRanges << Range.new(s, i - 1)
        end
        texts = []
        s = -1
      end
    end

    if not texts.empty? 
      textsList << texts
      textRanges << Range.new(s, loc.children.length-1)
    end

    # 段落の作成 これだと計2回走査になってしまうが。
    paragraphs = collectParagraphs(textsList)

    # 文のリストを段落で置き換え
    # これで計3回の走査
    # 逆順にすることで、削除に因るインデックス不整合を解消
    textRanges.reverse_each do |range| 
      loc.children[range] = Node.new(@id += 1, loc.children[range.first].level,
        paragraphs.pop, MARK_TEXT, loc)
    end

    # 空行を削除
    loc.children.reject! do |child| child.text == "" end
  end

  # 文章を段落ごとにまとめる
  def reduceLines(loc = @tree.root)
    reduceToParagraph(loc)

    loc.children.each do |child|
      if not [MARK_TEXT, MARK_COMMENT].include? child.mark
        reduceLines(child)
      end
    end
  end
end

# ========================================================= # 
# class: WordCorrector
# ========================================================= # 
# 文章の訂正(日本語、英語、マルチ全対応)
class WordCorrector
  include WordChecker
  # 厳密日本語形式で、空文字を挿入
  def insertEmptyChar(paragraph)
    if japaneseAny?(paragraph) and paragraph[0] != "　" 
      paragraph.insert(-paragraph.length-1, "　")
    end
  end

  # 、。を統一する
  def unifyPunctuation(tree)
    tree.each_node do |node|
      node.text.gsub!(/．/, "。");
      node.text.gsub!(/，/, "、");
    end
  end

  # 連続した句読点を除去
  # 最初だけ残して後は全て消す。
  # TODO 複数delimiterへの対応
  # @param p 句読点
  def removeExcessivePunctuation(tree, p)
    tree.each_node do |node|
      if i = node.text.index(p) != -1
        # i = node.text.index(p)
        while node.text[i+1] == p
          node.slice![i+1]
        end
      end
    end
  end

  # カッコ内の余計な空白を除去
  def removeExcessiveSpaceInBracket(paragraph)
    word = /[.,．，。、「」"`!?;\s][\w\-]+$/  # 区切り文字+切れている単語のパターン
  end

end

# ========================================================= # 
# class: LengthFormatter
# ========================================================= # 
# 日本語文章をn文字で適切に改行
class LengthFormatter
  include WordChecker
  @@EngWordMaxLength = 20
  @@DefaultColLength = 60
  @@DefaultHeaderLength = 80

  def initialize(tree, col = @@DefaultColLength, hcol = @@DefaultHeaderLength)
    @tree = tree
    if @tree.nil? then p "error: tree is null! in LengthFormatter." end
    @col = col
    @hcol = hcol
    if col < 0 then col = DefaultColLength end
    if hcol < 0 then col = DefaultHeaderLength end
  end

  # 特定要素の次にインサート 未使用
  def insertTextNode(node, text)
    if node.parent.nil?
      node.children.insert(0, Node.new(0, node.level, text, MARK_TEXT))
      puts node.children
    else
      node.parent.children.insert(node.children.index(node), 
        Node.new(0, node.level, text, MARK_TEXT))
    end
  end


  # 全角を2文字と数えて文字列長を取得する
  def multiLength(str, start = 0)
    # 文字をsからeまで数えて出力する
    counter = 0

    for i in start...str.length
      if fullWidthAll? str[i] then counter +=2
      else counter += 1
      end
    end
    counter
  end

  # 文字列中の特定の範囲の開始点と長さを求める。
  # 処理：長さの単位は全てマルチバイトを前提
  def multiPart(str, range)
    s = 0
    l = ml = multiLength(str)

    # 場合分け
    if range.instance_of?(Range)
      s = range.first.to_i
      l = range.last - range.first + 1
    elsif range.instance_of?(Fixnum)
      l = range
    end

    # チェック
    if l - s < -1 || l - s > ml
      l = ml - s
      p "error! l is not valid in multiPart"
    end

    # 文字をsからeまで数えて出力する
    counter = 0
    for i in s...str.length
      if l <= counter then break end
      if fullWidthAll? str[i] then counter +=2
      else counter += 1
      end
    end
    [s,i]
  end

  # 全角を2文字と数えて指定の長さを取得する
  def multiSlice(str, range)
    a = multiPart(str, range)
    str[a[0], a[1]]
  end

  def multiSlice!(str, range)
    a = multiPart(str, range)
    str.slice!(a[0], a[1])
  end

  # overload not worked
  # def multiSlice(str, start, length)
  #   multiSlice(str, start..(length-start-1))
  # end

  # 指定文字数で段落を分割する
  def addNewLine()
    @tree.each_node do |node|
      if node.mark =~ TREE_HEADER
        node.text = addNewLineLocal(node.text, @hcol)
      end
    end
    @tree.each_mark_node(MARK_TEXT) do |node|
      node.text = addNewLineLocal(node.text, @col)
    end
  end

  # 指定文字数で段落を分割する(node.text単位)
  def addNewLineLocal(text, col)
    dst = ""

    # p text, text.length
    # puts text
    # while @col < text.length
    while col < multiLength(text)
      # line = text.slice!(0..@col-1)
      line = multiSlice!(text, 0..col-1)
      line = correctPresentLine(line, text)
      dst += line + "\n"
    end
    dst += text

    # puts "newlined:"
    # p dst
    # puts dst
    dst
  end

  # 現在行を残りの文の文頭を考慮して修正
  def correctPresentLine(line, rest)
    line = correctPunctuation(line, rest)
    line = correctEnglishWord(line, rest)
    line
  end

  # 文頭に区切り文字が来る場合、それらを前の行に持ってくる
  # 注：スペースは無視
  # 小さい"つ"も追加
  def correctPunctuation(line, rest)
    # matcher = /[\\\/\[\]\(\)\{.,;:<>．，"!?！？「」【】『』]/
    matcher = /[.,;:．，。、!?！？っ]/
    if rest[0].match(matcher) then line += rest.slice!(0)
    end
    line
  end

  # 後方参照で、単語区切りの最後からの長さを探す(前に戻るという意味なので注意)
  # 2014/03/14 日本語も追加
  def findDelemiterBackward(line)
    # delimiter = /[.,．，「」"`!?;\s]/ # 区切り文字 \s.include [space, \t, \n] 
    word = /([^ -~｡-ﾟ]|[,．，「」"`!?;\s\d])[\w\-]+$/
    # 区切り文字+切れている単語のパターン

    # 切れている単語のインデックス
    # 注：インデックスは空白など区切り文字のインデックスになっている
    # line.length - line.scan(word)[0].length 
    w = line.scan(word)[0]
    if w.nil? then w = "" end
    line.length - multiLength(w)
  end

  # 英単語中に改行が入った場合の修正をする
  # ずっとスペースない場合は考えなくていいか
  def correctEnglishWord(line, rest)
    if alphabet?(line[-1]) and alphabet?(rest[0])
      # puts line
      # puts rest[0..10]
      i = findDelemiterBackward(line)
      # p i
      # p line[i..line.length-1]
      # 行の切れている単語部分を削除
      w = line.slice!(i..line.length-1).strip
      # 行の切れている単語部分を文頭に挿入
      rest.insert(-rest.length-1, w)
      # p line
      # p rest
    end
    line.strip
  end

end

# ========================================================= # 
# class: Indenter
# ========================================================= # 
# class Indenter
#   DefaultIndentLevel = 0
#   def initialize(tree, col = DefaultIndentLevel)
#     @tree = tree
#     @col = col
#   end

#   # ツリーのインデント
#   def indent(level = @col)
#     indent_local(@tree.root, level)
#   end
  
#   def indent_local(node, level)
#     # orgではヘッダはインデントしない
#     if node.mark =~ TREE_HEADER
#     elsif node.mark =~ TREE_OLIST or node.mark =~ TREE_ULIST
#       if node.parent =~ TREE_HEADER
#         node.text = " " * level  + node.text
#       else
#         node.text = " " * (node.parent.level * 2) + node.text
#       end
#       # node.text = " " * level  + node.text
#     else
#       if node.mark == MARK_ROOT
#         # puts "root::::"  + node.toString
#         # if node.parent.mark =~ TREE_OLIST or node.parent.mark =~ TREE_ULIST
#         #   node.text = node.text
#         # elsif node.mark = MARK_TEXT
#       elsif node.mark == MARK_TEXT
#         if node.parent.nil? then  puts "error: parent is nil:" + node.toString
#         elsif node.parent.mark =~ TREE_HEADER
#           node.text = " " * level + node.text
#         else
#         end
#         # node.text = " " * level + node.text
#         node.text.gsub!(/\n/, "\n" + " " * level)
#       end
#     end
#     node.children.each do |node|
#       indent_local(node, level + 1)
#     end
#   end
# end


# ========================================================= # 
# class: FileWriter
# ========================================================= # 
# treeをファイルに書き出す
class FileWriter
  def initialize(tree, file, outFormat = nil)
    @tree = tree
    @id = @tree.size                  # 仮idの設定
    @outFormat = outFormat
    @file = file
  end

  def toOrgHeaderMark(mark)
    if mark !~ TREE_HEADER
      p "error! mark is not valid in toOrgHeaderMark"
    else return "*" * mark[1,mark.length].to_i + " "
    end
  end

  # org-modeのフォーマットで出力
  def orgWrite()
    orgWriteRepeat(@tree.root, 0)
    p "file writing end"
  end

  def orgWriteRepeat(node, level)
    orgWriteLocal(node, level)
    node.children.each do |node|
      orgWriteRepeat(node, level + 1)
    end
  end

  def orgWriteLocal(node, level)
    if node.mark ==  MARK_TEXT
      # 親がリストの場合は、最初の段落はインデントしない
      if node.parent.mark =~ TREE_OLIST or node.parent.mark =~ TREE_ULIST
        @file.write(indent(node.text, level, true))
      else
        @file.write(indent(node.text, level))
      end
      @file.write("\n\n") #! 改行2回注意
      p "text"
      print node.text
      puts
    elsif node.mark =~ TREE_OLIST or node.mark =~ TREE_ULIST
      if (node.parent.mark =~ TREE_OLIST or node.parent.mark =~ TREE_ULIST) and
          node.parent.children.first == node
        @file.write("\n" + "  " * level + node.mark)
      else
        @file.write(" " * level + node.mark)
      end
      p "list"
      print (node.text)
      puts ("\n")
    elsif node.mark =~ TREE_HEADER
      @file.write(toOrgHeaderMark(node.mark))
      @file.write(node.text)
      @file.write("\n")
      p "header"
      print (node.text)
      puts
    end
  end

    # b
  def indent(text, level, b = false)
    dst = ""
    if b
      dst = dst + text.gsub(/\n/, "\n" + " " * (level + 1))
    else
      dst = " " * level
      dst = dst + text.gsub(/\n/, "\n" + " " * level)
    end
    dst
  end
  
  # file writing paragraph tree
  def writeTree(file)
    file.write @tree.toString
  end

  # フォーマットを伴う書き込み
  def write(file)
  end

  def close()
    @file.close
  end

  def writeHeader(pathStr)
    lines = []
    open(pathStr, "r").each do |line| lines << line end.close
    lines.each do |line|
      @file.write line
    end
  end
end



# ========================================================= # 
# group: main
# ========================================================= # 
PATH = ARGV[0]
# PATH = "indent.org"
# PATH = "grid.org"
# PATH = "test.org"
# PATH = "newline.org"
# PATH = "english-newline.org"
HeaderPath = "header.txt"
OUT = "out.org"
puts "open file:" + PATH.to_s

# root = Node.new(0, 0, NULL_TEXT, MARK_ROOT)
# tree = Tree.new root
# tree.genParagraphTree(read(PATH))
filePerser = FileParser.new(PATH)
tree = filePerser.tree
reducer = ParagraphReducer.new(tree)
reducer.reduceLines
# p tree.size
# tree.printTree
lformatter = LengthFormatter.new(tree, 60, 80)
lformatter.addNewLine
correcter = WordCorrector.new();
correcter.insertEmptyChar(tree);
correcter.unifyPunctuation(tree);
# indenter = Indenter.new(tree, 0)
# indenter.indent()
fileWriter = FileWriter.new(tree, open(OUT, "w"))
fileWriter.writeHeader(HeaderPath)
fileWriter.orgWrite
fileWriter.close

# text = "If you develop in a cave, on a single platform, and don't share your code with anyone then you can happily move on and not worry about line endings because the default settings in Git will suit you just fine. The rest of you, read on!"

# i = 23
# p lformatter.correctEnglishWord(text[0..i-1], text[i..text.length])
# p lformatter.findDelemiterBackward(text[0..i-1])
# l = lformatter.multiLength("123456789.文字を")
# puts l
# len = 9
# s = lformatter.multiSlice("文字をsからeまで", len)
# puts s
# s = lformatter.multiSlice("文字を", 3)
# puts s

puts ""

