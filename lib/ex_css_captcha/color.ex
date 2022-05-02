defmodule ExCSSCaptcha.Color do
  defstruct ~W[h s l]a

  defp create(hmin, hmax, smin, smax, lmin, lmax) do
    %__MODULE__{
      h: ExCSSCaptcha.random(hmin, hmax),
      s: ExCSSCaptcha.random(smin, smax),
      l: ExCSSCaptcha.random(lmin, lmax),
    }
  end

  def create(:red) do
    create(0, 30, 75, 100, 40, 60)
  end

  def create(:blue) do
    create(210, 240, 75, 100, 40, 60)
  end

  def create(:green) do
    create(90, 120, 75, 100, 40, 60)
  end

  def create(:light) do
    create(0, 359, 0, 50, 92, 100)
  end

  def create(:dark) do
    create(0, 359, 0, 100, 0, 6)
  end

  defp normalize_hue(h) when h < 0, do: h + 360
  defp normalize_hue(h) when h > 360, do: h - 360
  defp normalize_hue(h), do: h

  defp step2(h, m1, m2) when h < 60, do: m1 + (m2 - m1) * (h / 60)
  defp step2(h, _m1, m2) when h < 180, do: m2
  defp step2(h, m1, m2) when h < 240, do: m1 + (m2 - m1) * ((240 - h) / 60)
  defp step2(_h, m1, _m2), do: m1

  def hue_to_rgb(m1, m2, h) do
    h
    |> normalize_hue()
    |> step2(m1, m2)
    |> Kernel.*(255.5)
    |> Kernel.trunc()
  end

  def hsl_to_rgb(%__MODULE__{l: 0}), do: {0, 0, 0}
  def hsl_to_rgb(color = %__MODULE__{}) do
    s = color.s / 100
    l = color.l / 100
    m2 = if l <= 0.5 do
      l * (s + 1)
    else
      l + s - l * s
    end
    m1 = l * 2 - m2
    {hue_to_rgb(m1, m2, color.h + 120), hue_to_rgb(m1, m2, color.h), hue_to_rgb(m1, m2, color.h - 120)}
  end

  def format(color = %__MODULE__{}) do
    {r, g, b} = hsl_to_rgb(color)

    'color: #~2.16.0B~2.16.0B~2.16.0B;'
    |> :io_lib.format([r, g, b])
    |> to_string()
  end
end
