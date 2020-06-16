defmodule ExCSSCaptcha.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_css_captcha,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "ExCSSCaptcha",
      source_url: "https://github.com/julp/ex_css_captcha"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.4"},
      {:gettext, ">= 0.0.0"},
      {:phoenix_html, "~> 2.14"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A really simple (and visual only) captcha engine based on CSS3 and Unicode"
  end

  defp package() do
    [
      files: ["lib", "priv", "mix.exs", "README*"],
      licenses: ["BSD"],
      links: %{"GitHub" => "https://github.com/julp/ex_css_captcha"}
    ]
  end
end
