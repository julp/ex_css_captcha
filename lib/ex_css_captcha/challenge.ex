defmodule ExCSSCaptcha.Challenge do
  defstruct ~W[challenge digits]a

  @type t :: %__MODULE__{
    challenge: nonempty_charlist,
    digits: [{:significant | :irrelevant, char}],
  }

  @doc ~S"""
  TODO
  """
  def create(options \\ []) do
    options = ExCSSCaptcha.options(options)
    digits = Range.new(1, options.challenge_length + options.fake_characters_length)
    |> Enum.map(
      fn i ->
        {if(i <= options.challenge_length, do: :significant, else: :irrelevant), Enum.random(options.alphabet)}
      end
    )
    |> Enum.shuffle()
    %__MODULE__{
      challenge: digits
        |> Enum.reduce(
          [],
          fn
            {:significant, character}, acc ->
              [character | acc]
            _, acc ->
              acc
          end
        )
        |> Enum.reverse(),
      digits: digits,
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


  defp set_color(:significant, %{significant_characters_color: :nil}), do: []
  defp set_color(:significant, %{significant_characters_color: color}) do
    color
    |> ExCSSCaptcha.Color.create()
    |> ExCSSCaptcha.Color.format()
  end

  defp set_color(:irrelevant, %{fake_characters_color: :nil}), do: []
  defp set_color(:irrelevant, %{fake_characters_color: color}) do
    color
    |> ExCSSCaptcha.Color.create()
    |> ExCSSCaptcha.Color.format()
  end

  def set_style(:irrelevant, options), do: options.fake_characters_style || []
  def set_style(:significant, options), do: options.significant_characters_style || []

  @doc ~S"""
  TODO
  """
  def render(form, challenge = %__MODULE__{}, options \\ []) do
    use Phoenix.HTML
    options = ExCSSCaptcha.options(options)

    characters = challenge.digits
    |> Enum.with_index()

    lines = characters
    |> Task.async_stream(
      fn {{kind, char}, index} ->
        content = [ExCSSCaptcha.Table.map(char, options.unicode_version)]
        |> generate_noise(options)
        |> Enum.reverse()
        |> generate_noise(options)
        |> Enum.map(&encode_character/1)
        |> Enum.join()
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
          set_color(kind, options),
          set_style(kind, options),
          "}",
        ])
      end
    )
    |> Enum.map(fn {:ok, v} -> v end)

    css = characters
    |> handle_reversed(lines, options)
    |> Enum.shuffle()
    |> Enum.join("\n")

    html = content_tag(options.html_wrapper_tag, Enum.map(challenge.digits, fn _ -> content_tag(options.html_letter_tag, "") end), id: options.html_wrapper_id)
    options.renderer.render(form, ExCSSCaptcha.encrypt_and_sign(challenge.challenge), html, raw(css))
  end
end
