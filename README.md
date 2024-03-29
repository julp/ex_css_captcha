# ExCSSCaptcha

A really simple (and visual only) captcha engine based on CSS3 and Unicode (elixir "port" of [julp/CSS-captcha](https://github.com/julp/CSS-captcha)) :

* no need for any storage: the challenge is signed then ciphered to be directly transmitted by the client (hidden input)
* 2 code additions required

## Installation

~~If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `ex_css_captcha` to your list of dependencies in `mix.exs`:~~

```elixir
def deps do
  [
    {:ex_css_captcha, "~> 0.1.0"},
  ]
end
```

~~Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/ex_css_captcha](https://hexdocs.pm/ex_css_captcha).~~

## Configuration

Defaults are:

```elixir
config :ex_css_captcha,
  csp_nonce: nil,
  alphabet: '23456789abcdefghjkmnpqrstuvwxyz',
  reversed: false,
  noise_length: 2,
  challenge_length: 8,
  fake_characters_length: 2,
  unicode_version: :ascii,
  significant_characters_color: nil,
  fake_characters_color: nil,
  fake_characters_style: "display: none",
  html_wrapper_id: :captcha,
  html_letter_tag: :span,
  html_wrapper_tag: :div,
  significant_characters_style: "",
  renderer: ExCSSCaptcha.DefaultRenderer,
```

Where:

* csp_nonce (string): the nonce value used you previously generated for Content Security Policy (if any)
* alphabet (charlist): subset of ASCII alphanumeric characters from which to pick characters to generate the challenge (eg: define it to `'0123456789'` to only use digits)
* reversed (boolean): inverse order of displayed element (`false` to disable)
* noise_length (integer): define the maximum number of noisy characters to add before and after each character composing the challenge. A random number of whitespaces (may be punctuations in the future) will be picked between 0 and this maximum
* challenge_length (integer): challenge length (in characters)
* fake_characters_length (integer): number of irrelevant characters added to the challenge when displayed
* significant_characters_color (one of `nil` - none/inherit, `:blue`, `:red`, `:green`, `:light` (white-ish), `:dark` (black-ish)): generate a random nuance of the given color for significant characters
* fake_characters_color: same as *significant_characters_color* but for irrelevant characters integrated to the challenge
* html_wrapper_id (atom or string): HTML/CSS ID of container element
* html_wrapper_tag (atom or string): HTML tag name of container element
* html_letter_tag (atom or string): HTML tag to display challenge (and fake) characters
* significant_characters_style (string): fragment of CSS code to append to significant characters of the challenge
* fake_characters_style (string): fragment of CSS code to append to irrelevant characters of the challenge
* unicode_version (atom, one of `:ascii`, `:unicode_1_1_0`, `:unicode_2_0_0`, `:unicode_3_0_0`, `:unicode_3_1_0`, `:unicode_3_2_0`, `:unicode_4_0_0`, `:unicode_4_1_0`, `:unicode_5_0_0`, `:unicode_5_1_0`, `:unicode_5_2_0`, `:unicode_6_0_0`): the Unicode version from which to pick characters
* renderer (module): a module implementing `ExCSSCaptcha.Renderer` behaviour to customize HTML output for the captcha (see `ExCSSCaptcha.DefaultRenderer` for an example)

## Usage

First, generates the captcha from your controller:

```diff
+  @captcha_options [
+    # your custom options
+  ]

   defp render_new(conn, changeset = %Ecto.Changeset{}) do
     conn
     |> assign(:changeset, changeset)
+    |> assign(:challenge, ExCSSCaptcha.Challenge.create(@captcha_options))
     |> render(:new)
   end

   def new(conn, _params) do
      render_new(conn, change_foo())
   end

   def create(conn, _params = %{"foo_params" => foo_params}) do
     foo_params
     |> create_foo()
     |> case do
       {:ok, foo = %Foo{}} ->
         conn
         |> put_flash(:info, "foo successfully created")
         |> redirect(to: ~p"/")
         |> halt()
       {:error, changeset = %Ecto.Changeset{}} ->
         conn
         |> render_new(changeset)
     end
   end
```

Then, in your template, your form, insert the following to add the needed fields:

The old way:

```diff
 <%= form_for @changeset, ..., fn f -> %>
   ...

+  <%= ExCSSCaptcha.Challenge.render(f, @challenge) %>

   ...
 <% end %>
```

The new way, with components:

```eex
<.simple_form
  :let={f}
  for={@changeset}
  ...
>
  ...

  <div>
    <ExCSSCaptcha.Challenge.css_tag
      challenge={@challenge}
    />
    <.label for={@form[:captcha].id}>
      <%= ExCSSCaptcha.Gettext.dgettext("ex_css_captcha", "Copy the following code in the field below") %>
    </.label>
    <ExCSSCaptcha.Challenge.html_tag
      class="my-8"
      form={@form}
      challenge={@challenge}
    />
    <.input
      type="text"
      field={@form[:captcha]}
      name={Phoenix.HTML.Form.input_name(@form, :captcha)}
      autocomplete="off"
      value=""
    />
  </div>

  ...
</.simple_form>
```

Then, in your changeset function, just add the following validation:

```diff
   def changeset(struct, params) do
     struct
     ...
+    |> ExCSSCaptcha.validate_captcha()
   end
```
