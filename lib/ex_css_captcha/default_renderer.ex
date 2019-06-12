defmodule ExCSSCaptcha.DefaultRenderer do
  use ExCSSCaptcha.Renderer
  import ExCSSCaptcha.Gettext

  @impl ExCSSCaptcha.Renderer
  def render(form, signature, html, css) do
    [
      label(form, :captcha, dgettext("ex_css_captcha", "Copy the following code in the field below")),
      content_tag(:style, css, type: "text/css"),
      html,
      hidden_input(form, :captcha2, value: signature),
      text_input(form, :captcha, autocomplete: "off", value: ""), # value: "" to force empty value to clear the field
    ]
  end
end
