defmodule ExCSSCaptcha do
  @moduledoc """
  Documentation for ExCSSCaptcha.
  """

  @defaults [
    alphabet: '23456789abcdefghjkmnpqrstuvwxyz',
    reversed: false,
    noise_length: 2,
    challenge_length: 8,
    fake_characters_length: 2,
    #fake_characters_color: nil,
    significant_characters_color: nil,
    html_wrapper_id: :captcha,
    html_letter_tag: :span,
    html_wrapper_tag: :div,
    unicode_version: :ascii,
    #fake_characters_style: "display: none",
    significant_characters_style: "",
    renderer: ExCSSCaptcha.DefaultRenderer,
  ]

  def options(options) do
    @defaults
    |> Keyword.merge(Application.get_all_env(:ex_css_captcha))
    |> Keyword.merge(options)
    |> Enum.into(%{})
  end

  # TODO: move this to defaults/config
  @separator "/"
  @expires_in 300 # in seconds
  @algorithm "AES128GCM"
  @key :crypto.strong_rand_bytes(32) # (re)generated at compile time
  @pepper :crypto.strong_rand_bytes(24) # (re)generated at compile time
  def encrypt(content) do
    iv = :crypto.strong_rand_bytes(32)
    {ct, tag} = :crypto.block_encrypt(:aes_gcm, @key, iv, {@algorithm, content})
    Base.encode16(iv <> tag <> ct)
  end

  def decrypt(payload) do
    with <<iv::binary-32, tag::binary-16, ct::binary>> <- Base.decode16!(payload) do
      {:ok, :crypto.block_decrypt(:aes_gcm, @key, iv, {@algorithm, ct, tag})}
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

  def encrypt_and_sign(challenge) do
    content = [@pepper, challenge, DateTime.utc_now()]
    |> Enum.join(@separator)
    hash = content
    |> digest()
    [content, hash]
    |> Enum.join(@separator)
    |> encrypt()
  end

  def validate_captcha(changeset = %Ecto.Changeset{valid?: false}), do: changeset
  def validate_captcha(changeset = %Ecto.Changeset{params: %{"captcha" => captcha1, "captcha2" => captcha2}}) do
    import ExCSSCaptcha.Gettext
    captcha1 = String.downcase(captcha1)
    with(
      {:ok, data} when is_binary(data) <- decrypt(captcha2),
      [@pepper, ^captcha1, datetime, hash] <- String.split(data, @separator),
      ^hash <- [@pepper, captcha1, datetime]
      |> Enum.join(@separator)
      |> digest(),
      {:ok, datetime, 0} <- DateTime.from_iso8601(datetime)
    ) do
      if DateTime.diff(DateTime.utc_now(), datetime) > @expires_in do
        Ecto.Changeset.add_error(changeset, :captcha, dgettext("ex_css_captcha", "has expired"))
      else
        changeset
      end
    else
      value ->
        require Logger

        Logger.debug("captcha validation failed with: #{inspect(value)}")
        Ecto.Changeset.add_error(changeset, :captcha, dgettext("ex_css_captcha", "is invalid"))
    end
  end
end
