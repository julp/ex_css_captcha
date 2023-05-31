defmodule ExCSSCaptcha.Challenge do
  defstruct ~W[challenge digits options]a

  @type t :: %__MODULE__{
    challenge: nonempty_charlist,
    options: ExCSSCaptcha.Options.t,
    digits: [{:significant | :irrelevant, char}],
  }

  @doc ~S"""
  TODO (doc)
  """
  @spec create(options :: Enumerable.t) :: t
  def create(options \\ []) do
    options = ExCSSCaptcha.options(options)

    digits =
      Range.new(1, options.challenge_length + options.fake_characters_length)
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
      options: options,
    }
  end

  defp char_to_precision(char) when char > 0xFFFF, do: 6
  defp char_to_precision(_char), do: 4

  defp encode_character(char) do
    :io_lib.format('\\~*.16.0B', [char_to_precision(char), char])
  end

#   defp list_prepend(value, list) do
#     [value | list]
#   end

  defp generate_noise(list, %ExCSSCaptcha.Options{noise_length: 0}), do: list
  defp generate_noise(list, options) do
    ExCSSCaptcha.random(0, options.noise_length)
    |> case do
      # special case for none because Range.new(0, 0) |> Enum.to_list() gives [0]
      # and we finish with one character of noise instead of none
      0 ->
        list
      length ->
        Range.new(1, length)
        |> Enum.reduce(
          list,
          fn _, acc ->
            [ExCSSCaptcha.Table.map(?\s, options.unicode_version) | acc]
          end
        )
    end
  end

  defp handle_reversed(lines, characters, options = %ExCSSCaptcha.Options{reversed: true}) do
    Enum.reduce(
      characters,
      [IO.iodata_to_binary(["#", to_string(options.html_wrapper_id), " { display: flex; flex-direction: row-reverse; justify-content: flex-end; }"]) | lines],
      fn {_char, index}, acc ->
        line =
          IO.iodata_to_binary([
            "#",
            to_string(options.html_wrapper_id),
            " ",
            to_string(options.html_letter_tag),
            ":nth-child(",
            #"0n+",
            to_string(index + 1),
            ") { order: ",
            to_string(options.challenge_length - index),
            "; }",
          ])

        [line | acc]
      end
    )
  end
  defp handle_reversed(lines, _characters, _options), do: lines

  defp set_color(:significant, %ExCSSCaptcha.Options{significant_characters_color: nil}), do: []
  defp set_color(:significant, %ExCSSCaptcha.Options{significant_characters_color: color}) do
    color
    |> ExCSSCaptcha.Color.create()
    |> ExCSSCaptcha.Color.format()
  end

  defp set_color(:irrelevant, %ExCSSCaptcha.Options{fake_characters_color: nil}), do: []
  defp set_color(:irrelevant, %ExCSSCaptcha.Options{fake_characters_color: color}) do
    color
    |> ExCSSCaptcha.Color.create()
    |> ExCSSCaptcha.Color.format()
  end

  defp set_style(:irrelevant, options), do: options.fake_characters_style || []
  defp set_style(:significant, options), do: options.significant_characters_style || []

  defp challenge_to_css(challenge = %__MODULE__{}) do
    characters = challenge.digits |> Enum.with_index()

    characters
    |> Enum.map(
      fn {{kind, char}, index} ->
       content =
          char
          |> ExCSSCaptcha.Table.map(challenge.options.unicode_version)
          |> List.wrap()
          |> generate_noise(challenge.options)
          |> Enum.reverse()
          |> generate_noise(challenge.options)
          |> Enum.map(&encode_character/1)
          |> Enum.join()

        #"##{challenge.options.html_wrapper_id} #{challenge.options.html_letter_tag}:nth-child(#{index + 1}):after { content: \"#{content}\"; #{color} #{challenge.options.significant_characters_style} }\n"
        IO.iodata_to_binary([
          "#",
          to_string(challenge.options.html_wrapper_id),
          " ",
          to_string(challenge.options.html_letter_tag),
          ":nth-child(",
          to_string(index + 1),
          "):after { content: \"",
          content,
          "\";",
          set_color(kind, challenge.options),
          set_style(kind, challenge.options),
          "}",
        ])
      end
    )
    |> handle_reversed(characters, challenge.options)
    |> Enum.shuffle()
    |> Enum.join("\n")
  end

  if {:module, _module} = Code.ensure_compiled(Phoenix.Component) do
    use Phoenix.Component

    attr :challenge, __MODULE__, required: true
    def css_tag(assigns) do
      ~H"""
      <style nonce={@challenge.options.csp_nonce} type="text/css">
        <%= @challenge |> challenge_to_css() |> Phoenix.HTML.raw() %>
      </style>
      """
    end

    attr :challenge, __MODULE__, required: true
    attr :form, Phoenix.HTML.Form, required: true
    def html_tag(assigns) do
      ~H"""
      <Phoenix.Component.dynamic_tag name={@challenge.options.html_wrapper_tag} id={@challenge.options.html_wrapper_id}>
        <Phoenix.Component.dynamic_tag name={@challenge.options.html_letter_tag} :for={_ <- @challenge.digits}>
          <%# empty %>
        </Phoenix.Component.dynamic_tag>
        <input
          type="hidden"
          name={Phoenix.HTML.Form.input_name(@form, :captcha2)}
          value={ExCSSCaptcha.encrypt_and_sign(@challenge.challenge)}
        />
      </Phoenix.Component.dynamic_tag>
      """
    end
  end

  @doc ~S"""
  TODO (doc)
  """
  def render(form, challenge = %__MODULE__{}) do
    use Phoenix.HTML

    html =
      content_tag(
        challenge.options.html_wrapper_tag,
        Enum.map(
          challenge.challenge.digits,
          fn _ ->
            content_tag(challenge.options.html_letter_tag, "")
          end
        ),
        [
          id: challenge.options.html_wrapper_id,
        ]
      )
    css =
      content_tag(
        :style,
        challenge_to_css(challenge) |> Phoenix.HTML.raw(),
        [
          type: "text/css",
          nonce: challenge.options.csp_nonce,
        ]
      )

    challenge.options.renderer.render(form, ExCSSCaptcha.encrypt_and_sign(challenge.challenge), html, raw(css))
  end
end
