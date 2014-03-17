# -*- coding: utf-8 -*-

# ========================================================= # 
# module: WordChecker
# ========================================================= # 
# 文字の判定関数群
# 注：空文字は未考慮
module WordChecker
  # 半角文字(半角カナ含まず)が含まれるか判定
  def asciiAny?(str)
    !(str =~ /[[:ascii:]]/).nil?
  end

  # アスキーコードか?
  def ascii?(str)
    !(str =~ /\A[[:ascii:]]+\z/).nil?
  end

  # 文字がアルファベットか?
  def alphabet?(str)
    !(str =~ /\A[A-Za-z]+\z/).nil?
  end

  # 半角文字が含まれるか判定
  def halfWidthAny?(str)
    !(str =~ /[ -~｡-ﾟ]/).nil?
  end

  # 全角文字が含まれるか判定
  def fullWidthAny?(str)
    !(str =~ /[^ -~｡-ﾟ]/).nil?
  end

  # すべて半角文字かを判定
  def halfWidthAll?(str)
    !(str =~ /\A[ -~｡-ﾟ]+\z/).nil?
  end

  # すべて全角文字かを判定
  def fullWidthAll?(str)
    !(str =~ /\A[^ -~｡-ﾟ]+\z/).nil?
  end

  # 日本語が含まれるか判定
  # 非ASCIIと全角空白と区切りを抜いた文字
  def japaneseAny?(str, encode="utf")
    utf = /[ぁ-んァ-ヴ一-龠]/u
    # shiftJis = /[ぁ-んァ-ヴ亜-煕]/s

    case encode
    when "utf", "utf-8", "utf-16"
      return !(str =~ utf).nil?
      # when "shift-jis"
      #   return !(str =~ shiftJis).nil?
    end
  end

  # 英語が含まれるか判定
  def englishAny?(str)
    !(str =~ /[A-Za-z]/).nil?
  end

  # 英語の文か?
  # 不十分　難しいな
  def englishAll?(str)
    !(str =~ /^([.,"`!?;\s]*([A-Z]+|[a-z]+|[A-z][a-z]+)[.,"`!?;\s]*)+/).nil?
  end
end
