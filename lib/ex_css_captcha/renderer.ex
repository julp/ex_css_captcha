defmodule ExCSSCaptcha.Renderer do
  @callback render(form :: Phoenix.HTML.Form.t, signature :: String.t, html :: Phoenix.HTML.safe, css :: Phoenix.HTML.safe) :: Phoenix.HTML.safe

  defmacro __using__(_opts) do
    quote do
      use Phoenix.HTML
      @behaviour unquote(__MODULE__)
    end
  end
end
