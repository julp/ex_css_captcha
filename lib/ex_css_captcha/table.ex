defmodule ExCSSCaptcha.Table do
  def map(digit)
    when digit in '23456789'
  do
    [digit]
  end

  for letter <- 'abcdefghjkmnpqrstuvwxyz' do
    def map(unquote(letter)) do
      [unquote(letter), unquote(:string.to_upper(letter))]
    end
  end
end
