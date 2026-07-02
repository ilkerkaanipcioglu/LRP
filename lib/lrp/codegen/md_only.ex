defmodule LRP.Codegen.MdOnly do
  @moduledoc """
  md-only çıktı üretici.

  Kullanıcı hiç kod yazmadan yeni sisteminin yapısını, sorumluluklarını ve
  geçiş yolunu .md dosyaları olarak belgeler.

  ## Çıktı Yapısı
  docs/lrp-design/
  ├── README.md                          ← sistemin genel anatomisi
  ├── capabilities/
  │   ├── email.md
  │   └── accounting.md
  └── providers/
      ├── email-internal-md.md
      └── email-gmail.md

  ## Önemli
  Bu modül yalnızca yerel dosyalar üretir.
  Harici akışlara (Activepieces vb.) besleme YAPILMAZ.
  """

  @doc """
  Capability için .md tasarım belgesi üretir.

  ## Parametreler
  - `capability_type`    — "email" | "slack" | "accounting" | ...
  - `output_dir`         — hedef dizin (varsayılan: "docs/lrp-design")
  - `opts`               — [interface_contract:, providers:, description:]
  """
  @spec generate_capability(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_capability(capability_type, output_dir \\ "docs/lrp-design", opts \\ []) do
    dir      = Path.join(output_dir, "capabilities")
    filepath = Path.join(dir, "#{capability_type}.md")

    content = capability_template(capability_type, opts)

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  Provider için .md tasarım belgesi üretir.
  """
  @spec generate_provider(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_provider(capability_type, provider_type, output_dir \\ "docs/lrp-design", opts \\ []) do
    dir      = Path.join(output_dir, "providers")
    filename = "#{capability_type}-#{provider_type}.md"
    filepath = Path.join(dir, filename)

    content = provider_template(capability_type, provider_type, opts)

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  Tüm sistemin genel anatomisini özetleyen README üretir.
  """
  @spec generate_readme([String.t()], String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_readme(capability_types, output_dir \\ "docs/lrp-design", opts \\ []) do
    filepath = Path.join(output_dir, "README.md")
    content  = readme_template(capability_types, opts)

    with :ok <- File.mkdir_p(output_dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  Onboarding wizard'dan gelen verileri alıp tüm .md yapısını üretir.
  """
  @spec generate_all(map()) :: {:ok, [String.t()]} | {:error, term()}
  def generate_all(%{capabilities: capabilities, output_dir: output_dir} = _opts) do
    results =
      Enum.map(capabilities, fn cap ->
        cap_type  = cap[:type]
        providers = cap[:providers] || [%{type: "internal_md"}]

        with {:ok, cap_path} <- generate_capability(cap_type, output_dir,
                                   interface_contract: cap[:interface_contract],
                                   description: cap[:description]) do
          prov_paths =
            Enum.map(providers, fn prov ->
              {:ok, path} = generate_provider(cap_type, prov[:type], output_dir,
                               description: prov[:description],
                               upgrade_to: prov[:upgrade_to])
              path
            end)

          [cap_path | prov_paths]
        end
      end)
      |> List.flatten()

    capability_types = Enum.map(capabilities, & &1[:type])
    {:ok, readme_path} = generate_readme(capability_types, output_dir)

    {:ok, [readme_path | results]}
  end

  # ── Şablonlar ─────────────────────────────────────────────────────────────────

  defp capability_template(capability_type, opts) do
    interface = opts[:interface_contract] || default_interface(capability_type)
    desc      = opts[:description] || "#{capability_type} capability"
    date      = Date.utc_today() |> Date.to_string()

    interface_lines =
      interface
      |> Enum.map(fn {fn_name, fn_desc} -> "- `#{fn_name}` → #{fn_desc}" end)
      |> Enum.join("\n")

    yaml_interface =
      interface
      |> Enum.map(fn {fn_name, fn_desc} -> "  #{fn_name}: \"#{fn_desc}\"" end)
      |> Enum.join("\n")

    """
    ---
    capability: #{capability_type}
    description: "#{desc}"
    created_at: #{date}
    interface_contract:
    #{yaml_interface}
    ---

    # CAPABILITY: #{capability_type}

    > **Bu dosya bir md-only tasarım belgesidir — henüz kod üretilmemiştir.**
    > Elixir koduna yükseltmek için: `mix lrp.upgrade --from=md-only --to=elixir`

    **Oluşturulma:** #{date}
    **Açıklama:** #{desc}

    ---

    ## Interface Contract

    Bu capability'yi implemente eden her provider aşağıdaki fonksiyonları sağlamalıdır:

    #{interface_lines}

    ---

    ## Aktif Provider

    > Bağlı provider için `providers/#{capability_type}-*.md` dosyalarına bakın.

    ---

    ## MATURITY_SCORE

    | Metrik | Değer |
    |--------|-------|
    | Score | %0 (gözlem yok) |
    | Coverage | %0 |
    | Days Observed | 0 |
    | Recommendation | — |

    > Devreye alma kararı kullanıcıya aittir. Sistem otomatik geçiş YAPAMAZ.

    ---

    ## Geçiş Yolu

    ```
    internal_md (şu an) → external_app → elixir_module
    shadow → partial → primary → full_cutover
    ```

    Her aşama değişikliği kullanıcı onayı gerektirir.
    """
  end

  defp provider_template(capability_type, provider_type, opts) do
    desc       = opts[:description] || provider_type_description(provider_type)
    upgrade_to = opts[:upgrade_to]
    date       = Date.utc_today() |> Date.to_string()

    upgrade_section =
      if upgrade_to do
        """

        ## Upgrade Hedefi

        - Hedef provider_type: `#{upgrade_to}`
        - Geçiş: shadow → partial → primary → full_cutover
        - Veri kaybı riski: Yok (eski provider deprecated olarak saklanır)
        """
      else
        ""
      end

    """
    ---
    provider: #{capability_type}-#{provider_type}
    capability: #{capability_type}
    provider_type: #{provider_type}
    created_at: #{date}
    version: v1.0.0
    status: standby
    upgrade_to: #{upgrade_to || "null"}
    ---

    # PROVIDER: #{capability_type} / #{provider_type}

    > **Bu dosya bir md-only tasarım belgesidir.**

    **Oluşturulma:** #{date}
    **Capability:** #{capability_type}
    **Provider Type:** #{provider_type}
    **Açıklama:** #{desc}

    ---

    ## Sorumluluk

    #{provider_responsibility(provider_type, capability_type)}

    ---

    ## Provider Ref (Yapılandırma)

    ```json
    {
      "provider_type": "#{provider_type}",
      "path": "docs/lrp-design/providers/#{capability_type}-#{provider_type}.md"
    }
    ```

    ---

    ## Durum

    - **Status:** standby
    - **Version:** v1.0.0
    #{upgrade_section}
    """
  end

  defp readme_template(capability_types, opts) do
    system_name = opts[:system_name] || "LRP Sistemi"
    date        = Date.utc_today() |> Date.to_string()

    cap_list =
      capability_types
      |> Enum.map(fn t -> "- [#{t}](capabilities/#{t}.md)" end)
      |> Enum.join("\n")

    """
    # #{system_name} — LRP Tasarım Belgesi

    > **md-only modunda oluşturuldu — bu dizin kod içermez, sistem anatomisini belgeler.**
    > Elixir koduna yükseltmek için: `mix lrp.upgrade --from=md-only --to=elixir`

    **Oluşturulma:** #{date}

    ---

    ## Capability'ler

    #{cap_list}

    ---

    ## Provider Türleri

    | Tür | Açıklama |
    |-----|----------|
    | `internal_md` | Salt .md — manuel insan işlemi, kod yok |
    | `external_app` | Dış uygulama (Gmail, Slack vb.) |
    | `elixir_module` | Yerel Elixir modülü |
    | `agent` | AI agent |
    | `human` | Göreve atanmış insan |

    ---

    ## Geçiş Modeli

    ```
    shadow → partial → primary → full_cutover
    ```

    Her aşama geçişi kullanıcı kararı gerektirir. Sistem otomatik geçiş YAPMAZ.

    ---

    ## Upgrade Komutu

    ```bash
    mix lrp.upgrade --from=md-only --to=elixir
    ```

    Bu komut bu dizindeki .md dosyalarını okuyup Elixir migration + schema + context üretir.
    """
  end

  defp default_interface("email") do
    [
      {"create_message/1", "yeni mesaj oluştur"},
      {"read_inbox/1", "gelen kutusu listesi"},
      {"classify_message/2", "agent ile sınıflandır"},
      {"archive_message/1", "mesajı arşivle"},
      {"search/2", "mesajlarda arama"}
    ]
  end

  defp default_interface("slack") do
    [
      {"send_message/2", "kanal veya kullanıcıya mesaj gönder"},
      {"read_channel/1", "kanal mesajlarını oku"},
      {"create_thread/2", "yeni thread başlat"}
    ]
  end

  defp default_interface("accounting") do
    [
      {"post_journal/2", "muhasebe kaydı oluştur"},
      {"get_balance/2", "hesap bakiyesi"},
      {"generate_report/2", "dönem raporu"}
    ]
  end

  defp default_interface(_) do
    [{"execute/1", "işlemi gerçekleştir"}, {"status/1", "durum sorgula"}]
  end

  defp provider_type_description("internal_md"),   do: "Salt .md dosyası — manuel insan işlemi, çalışan kod yok"
  defp provider_type_description("external_app"),  do: "Dış uygulama entegrasyonu (API/webhook)"
  defp provider_type_description("elixir_module"), do: "Yerel Elixir modülü"
  defp provider_type_description("agent"),         do: "AI agent olarak sarılmış provider"
  defp provider_type_description("human"),         do: "Göreve atanmış insan"
  defp provider_type_description(other),           do: other

  defp provider_responsibility("internal_md", cap_type) do
    "Bu provider'da #{cap_type} işlemleri **manuel olarak insan tarafından** gerçekleştirilir. " <>
    "Herhangi bir kod çalışmaz. Bu dosya söz konusu sürecin nasıl çalışacağını belgeler."
  end

  defp provider_responsibility("external_app", cap_type) do
    "Bu provider'da #{cap_type} işlemleri **harici bir uygulama** üzerinden " <>
    "API/webhook ile gerçekleştirilir. Connector yapılandırması provider_ref içinde tutulur."
  end

  defp provider_responsibility(ptype, cap_type) do
    "Bu provider'da #{cap_type} işlemleri `#{ptype}` türünde bir provider ile yürütülür."
  end
end
