defmodule ExCSSCaptcha.Challenge do
  defstruct ~W[challenge fakes]a

  def create(options \\ []) do
    options = ExCSSCaptcha.options(options)
    range = Range.new(1, options.challenge_length)
    %__MODULE__{
      challenge: range
      |> Enum.map(
        fn _ ->
          Enum.random(options.alphabet)
          |> ExCSSCaptcha.Table.map()
          |> Enum.random()
        end
      ),
      fakes: range
      |> Enum.to_list()
      |> Enum.shuffle()
      |> Enum.take(options.fake_characters_length)
      |> Enum.into(%{}, fn offset ->
          {
            offset,
            Enum.random(options.alphabet)
            |> ExCSSCaptcha.Table.map()
            |> Enum.random()
          }
        end
      )
    }
  end

  @noise [ # [\p{Z}\p{Pc}\p{Pd}]
    0x0020, 0x002D, 0x005F, 0x00A0, 0x05BE, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2028,
    0x2029, 0x203F, 0x2040, 0x3000, 0x301C, 0x3030, 0xFE31, 0xFE32, 0xFE33, 0xFE34, 0xFE4D, 0xFE4E, 0xFE4F, 0xFE58, 0xFE63, 0xFF0D, 0xFF3F, 0x058A, 0x1680, 0x1806, 0x202F, 0x205F, 0x30A0,
    0x2054, 0x2E17, 0x1400, 0x2E1A, 0x2E3A, 0x2E3B, 0x2E40,
  ]

  defp char_to_precision(char) when char > 0xFFFF, do: 6
  defp char_to_precision(_char), do: 4

  defp encode_character(char) do
    :io_lib.format('\\~*.16.0B', [char_to_precision(char), char])
  end

  #defp list_prepend(list, value) do
    #[value | list]
  #end

  defp generate_noise(list, options) do
    Range.new(0, options.noise_length)
    |> Enum.random()
    |> case do
      # special case for none because Range.new(0, 0) |> Enum.to_list() gives [0]
      # and we finish with one character of noise instead of none
      0 ->
        list
      length ->
        Range.new(1, length)
        |> Enum.into(list, fn _ -> Enum.random(@noise) end)
    end
  end

  defp handle_reversed(characters, list, options = %{reversed: true}) do
    Enum.into(characters, [IO.iodata_to_binary(["#", to_string(options.html_wrapper_id), " { display: flex; flex-direction: row-reverse; justify-content: flex-end; }"]) | list], fn {_char, index} ->
      IO.iodata_to_binary([
        "#", to_string(options.html_wrapper_id), " ", to_string(options.html_letter_tag), ":nth-child(",
        #"0n+",
        to_string(index + 1), ") { order: ", to_string(options.challenge_length - index), "; }"
      ])
    end)
  end
  defp handle_reversed(_characters, list, _options), do: list

  def render(form, challenge = %__MODULE__{}, options \\ []) do
    use Phoenix.HTML
    options = ExCSSCaptcha.options(options)

    characters = challenge.challenge
    |> Enum.with_index()

    lines = characters
    |> Enum.map(
      fn {char, index} ->
        content = [char]
        |> generate_noise(options)
        |> Enum.reverse()
        |> generate_noise(options)
        |> Enum.map(&encode_character/1)
        |> Enum.join()
        color = case options.significant_characters_color do
          nil ->
            []
          atom ->
            atom
            |> ExCSSCaptcha.Color.create()
            |> ExCSSCaptcha.Color.format()
        end
        #"##{options.html_wrapper_id} #{options.html_letter_tag}:nth-child(#{index + 1}):after { content: \"#{content}\"; #{color} #{options.significant_characters_style} }\n"
        IO.iodata_to_binary([
          "#",
          to_string(options.html_wrapper_id),
          " ",
          to_string(options.html_letter_tag),
          ":nth-child(",
          to_string(index + 1),
          "):after { content: \"",
          content,
          "\";",
          color,
          options.significant_characters_style,
          "}",
        ])
      end
    )

    css = characters
    |> handle_reversed(lines, options)
    |> Enum.shuffle()
    |> Enum.join("\n")

    html = content_tag(options.html_wrapper_tag, Enum.map(challenge.challenge, fn _ -> content_tag(options.html_letter_tag, "") end), id: options.html_wrapper_id)
    options.renderer.render(form, ExCSSCaptcha.encrypt_and_sign(challenge.challenge), html, {:safe, css})
  end
end
