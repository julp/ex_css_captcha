defmodule ExCSSCaptcha do
  # generation options
  @default_alphabet ~C[23456789abcdefghjkmnpqrstuvwxyz]
  @default_noise_length 2
  @default_challenge_length 8
  @default_fake_characters_length 2
  @default_unicode_version :ascii

  # display options
  @default_reversed false
  @default_fake_characters_color nil
  @default_significant_characters_color nil
  @default_html_wrapper_id :captcha
  @default_html_letter_tag :span
  @default_html_wrapper_tag :div
  @default_fake_characters_style "display: none"
  @default_significant_characters_style ""

  @moduledoc """
  Documentation for ExCSSCaptcha.

  Options for challenge generation:

    * alphabet (charlist, default: `#{inspect(@default_alphabet)}`): subset of ASCII alphanumeric characters from which to pick characters to generate the challenge (eg: define it to `~C[0123456789]` to only use digits)
    * (required for display by CSS) challenge_length (integer, default: `#{inspect(@default_challenge_length)}`): challenge length
    * fake_characters_length (integer, default: `#{inspect(@default_fake_characters_length)}`): number of irrelevant characters added to the challenge when displayed (`0` to disable)
    * (required for display by CSS) unicode_version (atom, default: `#{inspect(@default_unicode_version)}`): set maximum version of Unicode from which to pick up code points (redefine it with one the "constants" `:unicode_1_1_0`, `:unicode_2_0_0`, `:unicode_3_0_0`, `:unicode_3_1_0`, `:unicode_3_2_0`, `:unicode_4_0_0`, `:unicode_4_1_0`, `:unicode_5_0_0`, `:unicode_5_1_0`, `:unicode_5_2_0`, `:unicode_6_0_0`). `:ascii` can be used here to not use Unicode.

  Display options:

    * (CSS) noise_length (integer, default: `#{inspect(@default_noise_length)}`): define the maximum number of noisy characters to add before and after each character composing the challenge. A random number of whitespaces (may be punctuations in the future) will be picked between `0` and this maximum (`0` for none)
    * (CSS) reversed (boolean, default: `#{inspect(@default_reversed)}`): if `true` inverse order of displayed element
    * (CSS) fake_characters_color (atom, default: `#{inspect(@default_fake_characters_color)}`): one "constant" among `:red`, `:green`, `:blue`, `:light`, `:dark` to generate a random nuance of the given color
    * (CSS) significant_characters_color (atom, default: `#{inspect(@default_significant_characters_color)}`): one "constant" among `:red`, `:green`, `:blue`, `:light`, `:dark` to generate a random nuance of the given color
    * (HTML + CSS) html_wrapper_id (atom or binary, default: `#{inspect(@default_html_wrapper_id)}`): HTML/CSS ID of container element (remember to keep unique for your entire generated webpage)
    * (HTML + CSS) html_letter_tag (atom or binary, default: `#{inspect(@default_alphabet)}`): HTML tag to display challenge (and fake) characters
    * (HTML) html_wrapper_tag (atom or binary, default: `#{inspect(@default_html_wrapper_tag)}`): HTML tag name of container element
    * (CSS) fake_characters_style (binary, default: `#{inspect(@default_fake_characters_style)}`): fragment of CSS code to append to irrelevant characters of the challenge
    * (CSS) significant_characters_style (binary, default: `#{inspect(@default_significant_characters_style)}`): fragment of CSS code to append to significant characters of the challenge
    * (CSS) csp_nonce (binary or nil for none, default: `nil`): if not `nil`, the value to set as nonce attribute for the `<style>` tag to comply with your Content-Security-Policy
  """

  require ExCSSCaptcha.Gettext

  @defaults [
    alphabet: @default_alphabet,
    reversed: @default_reversed,
    noise_length: @default_noise_length,
    challenge_length: @default_challenge_length,
    fake_characters_length: @default_fake_characters_length,
    fake_characters_color: @default_fake_characters_color,
    significant_characters_color: @default_significant_characters_color,
    html_wrapper_id: @default_html_wrapper_id,
    html_letter_tag: @default_html_letter_tag,
    html_wrapper_tag: @default_html_wrapper_tag,
    unicode_version: @default_unicode_version,
    fake_characters_style: @default_fake_characters_style,
    significant_characters_style: @default_significant_characters_style,
    renderer: ExCSSCaptcha.DefaultRenderer,
    csp_nonce: nil,
  ]

if false do
  defmodule Config do
    defstruct alphabet: '23456789abcdefghjkmnpqrstuvwxyz',
      reversed: false,
      noise_length: 2,
      challenge_length: 8,
      fake_characters_length: 2,
      fake_characters_color: nil,
      significant_characters_color: nil,
      html_wrapper_id: :captcha,
      html_letter_tag: :span,
      html_wrapper_tag: :div,
      unicode_version: :ascii,
      fake_characters_style: "display: none",
      significant_characters_style: "",
      renderer: ExCSSCaptcha.DefaultRenderer,
      csp_nonce: nil,
      separator: "/",
      expires_in: 300, # in seconds
      algorithm: "AES128GCM",
      key: :crypto.strong_rand_bytes(32), # (re)generated at compile time
      pepper: :crypto.strong_rand_bytes(24) # (re)generated at compile time

    @type color :: nil | :red | :green | :blue | :dark | :light

    @type t :: %__MODULE__{
      # generation options
      alphabet: nonempty_charlist,
      # NOTE: non_neg_integer includes 0 but not pos_integer
      noise_length: non_neg_integer,
      challenge_length: pos_integer,
      fake_characters_length: non_neg_integer,
      # display options
      reversed: nil | boolean,
      fake_characters_color: color,
      significant_characters_color: color,
      html_wrapper_id: atom,
      html_letter_tag: atom,
      html_wrapper_tag: atom,
      unicode_version: ExCSSCaptcha.Table.unicode_version,
      fake_characters_style: nil | String.t,
      significant_characters_style: nil | String.t,
      renderer: module,
      csp_nonce: nil | String.t,
      # display/(en|de)coding options
      separator: String.t,
      expires_in: pos_integer,
      algorithm: String.t,
      key: binary,
      pepper: binary,
    }

    @doc ~S"""
    TODO (doc)
    """
    @spec merge(config :: t, options :: Keyword.t) :: t
    def merge(config = %__MODULE__{}, _options) do
      # TODO
      config
    end
  end
end

  def options(options) do
    @defaults
    |> Keyword.merge(Application.get_all_env(:ex_css_captcha))
    |> Keyword.merge(options)
    |> Enum.into(%{})
  end

  System.otp_release()
  |> String.to_integer()
  |> Kernel.>=(23)
  |> if do
    @aeadtype :aes_256_gcm

    defp crypto_block_encrypt(aeadtype, key, ivec, {aad, plaintext}) do
      :crypto.crypto_one_time_aead(aeadtype, key, ivec, plaintext, aad, true)
    end

    defp crypto_block_decrypt(aeadtype, key, ivec, {aad, ciphertext, ciphertag}) do
      :crypto.crypto_one_time_aead(aeadtype, key, ivec, ciphertext, aad, ciphertag, false)
    end
  else
    @aeadtype :aes_gcm

    defp crypto_block_encrypt(aeadtype, key, ivec, tuple = {_aad, _plaintext}) do
      :crypto.block_encrypt(aeadtype, key, ivec, tuple)
    end

    defp crypto_block_decrypt(aeadtype, key, ivec, tuple = {_aad, _ciphertext, _ciphertag}) do
      :crypto.block_decrypt(aeadtype, key, ivec, tuple)
    end
  end

  @separator "/"
  @expires_in 300 # in seconds
  @algorithm "AES128GCM"
  @key :crypto.strong_rand_bytes(32) # (re)generated at compile time
  @pepper :crypto.strong_rand_bytes(24) # (re)generated at compile time

  def encrypt(content) do
    iv = :crypto.strong_rand_bytes(32)
    {ct, tag} = crypto_block_encrypt(@aeadtype, @key, iv, {@algorithm, content})
    Base.encode16(iv <> tag <> ct)
  end

  def decrypt(payload) do
    with(
      <<iv::binary-32, tag::binary-16, ct::binary>> <- Base.decode16!(payload),
      data when data != :error <- crypto_block_decrypt(@aeadtype, @key, iv, {@algorithm, ct, tag})
    ) do
      {:ok, data}
    else
      _ ->
        :error
    end
  end

  def digest(content) do
    content
    |> :erlang.md5()
    |> Base.encode16()
  end

  @doc ~S"""
  Generate a random number as [n1;n2]
  """
  @spec random(n1 :: integer, n2 :: integer) :: integer
  def random(n, n), do: n

  def random(n1, n2)
    when is_integer(n1) and is_integer(n2)
  do
    :rand.uniform(n2 - n1 + 1) + n1 - 1
  end

  @doc ~S"""
  Generate a random number as [n1;n2]
  """
  @spec random(n :: Range.t) :: integer
  def random(n1..n2) do
    random(n1, n2)
  end

  def encrypt_and_sign(challenge) do
    content =
      [
        @pepper,
        challenge,
        DateTime.utc_now(),
      ]
      |> Enum.join(@separator)
    hash = content |> digest()

    [content, hash]
    |> Enum.join(@separator)
    |> encrypt()
  end

  @length 32
  [captcha, captcha2] =
    1..2
    |> Enum.map(
      fn _ ->
        @length
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64()
        |> binary_part(0, @length)
      end
    )

  @doc ~S"""
  To bypass captchas in tests
  """
  def bypass_captcha(params) do
    params
    |> Map.put("captcha", unquote(captcha))
    |> Map.put("captcha2", unquote(captcha2))
  end

  @doc ~S"""
  The translated string to display when the captcha is invalid (meaning user answer doesn't match the challenge)
  """
  @spec invalid_captcha_message() :: String.t
  def invalid_captcha_message do
    ExCSSCaptcha.Gettext.dgettext("ex_css_captcha", "is invalid")
  end

  @doc ~S"""
  The translated string to display when the captcha has expired
  """
  @spec expired_captcha_message() :: String.t
  def expired_captcha_message do
    ExCSSCaptcha.Gettext.dgettext("ex_css_captcha", "has expired")
  end

  @doc ~S"""
  TODO (doc)
  """
  @spec validate_captcha(user_input :: String.t, private_data :: String.t) :: :ok | {:error, String.t}
  def validate_captcha(unquote(captcha), unquote(captcha2)), do: :ok
  def validate_captcha(user_input, private_data) do
    user_input = String.downcase(user_input)
    with(
      {:ok, data} when is_binary(data) <- decrypt(private_data),
      [@pepper, ^user_input, datetime, hash] <- String.split(data, @separator),
      ^hash <- [@pepper, user_input, datetime] |> Enum.join(@separator) |> digest(),
      {:ok, datetime, 0} <- DateTime.from_iso8601(datetime)
    ) do
      if DateTime.diff(DateTime.utc_now(), datetime) > @expires_in do
        {:error, expired_captcha_message()}
      else
        :ok
      end
    else
      value ->
        require Logger

        Logger.debug("captcha validation failed with: #{inspect(value)}")
        {:error, invalid_captcha_message()}
    end
  end

  @doc ~S"""
  TODO (doc)
  """
  @spec validate_captcha(changeset :: Ecto.Changeset.t) :: Ecto.Changeset.t
  def validate_captcha(changeset = %Ecto.Changeset{valid?: false}), do: changeset

  def validate_captcha(changeset = %Ecto.Changeset{params: %{"captcha" => user_input, "captcha2" => private_data}}) do
    case validate_captcha(user_input, private_data) do
      :ok ->
        changeset
      {:error, reason} ->
        Ecto.Changeset.add_error(changeset, :captcha, reason)
    end
  end

  # at least one of the params captcha/captcha2 is missing
  def validate_captcha(changeset = %Ecto.Changeset{}) do
    Ecto.Changeset.add_error(changeset, :captcha, invalid_captcha_message())
  end
end
