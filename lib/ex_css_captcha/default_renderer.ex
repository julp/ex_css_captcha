defmodule ExCSSCaptcha.DefaultRenderer do
  use ExCSSCaptcha.Renderer
  import ExCSSCaptcha.Gettext

#   for color <- ~W[red blue green light dark] do
#     ExCSSCaptcha.Gettext.dgettext_noop("ex_css_captcha", unquote(color))
#   end

  @impl ExCSSCaptcha.Renderer
  def render(form, signature, html, css) do
#     label = if color = options.significant_characters_color do
#       dgettext("ex_css_captcha", "Copy the following code, only the %{color} characters, in the field below", color: dgettext("ex_css_captcha", to_string(color)))
#     else
#       dgettext("ex_css_captcha", "Copy the following code in the field below")
#     end
    [
      label(form, :captcha, dgettext("ex_css_captcha", "Copy the following code in the field below")),
      css,
      html,
      hidden_input(form, :captcha2, value: signature),
      text_input(form, :captcha, autocomplete: "off", value: ""), # value: "" to force empty value to clear the field
    ]
  end
end
