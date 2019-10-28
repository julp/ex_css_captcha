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
          }
        end
      )
    }
  end

  defp char_to_precision(char) when char > 0xFFFF, do: 6
  defp char_to_precision(_char), do: 4

  defp encode_character(char) do
    :io_lib.format('\\~*.16.0B', [char_to_precision(char), char])
  end

  #defp list_prepend(list, value) do
    #[value | list]
  #end

  defp generate_noise(list, %{noise_length: 0}), do: list

  defp generate_noise(list, options) do
    ExCSSCaptcha.random(0, options.noise_length)
    |> case do
      # special case for none because Range.new(0, 0) |> Enum.to_list() gives [0]
      # and we finish with one character of noise instead of none
      0 ->
        list
      length ->
        Range.new(1, length)
        |> Enum.into(list, fn _ -> ExCSSCaptcha.Table.map(?\s, options.unicode_version) end)
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
        content = [ExCSSCaptcha.Table.map(char, options.unicode_version)]
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
