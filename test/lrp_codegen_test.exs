defmodule LRP.CodegenTest do
  use ExUnit.Case, async: false
  alias LRP.Codegen.{MdOnly, ElixirGenerator}

  setup do
    # Testler için geçici dizinler tanımla
    tmp_md_dir = Path.join([File.cwd!(), "tmp", "lrp-design-test"])
    tmp_lib_dir = Path.join([File.cwd!(), "tmp", "lib-test"])
    tmp_mig_dir = Path.join([File.cwd!(), "tmp", "mig-test"])

    File.mkdir_p!(tmp_md_dir)
    File.mkdir_p!(tmp_lib_dir)
    File.mkdir_p!(tmp_mig_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join(File.cwd!(), "tmp"))
    end)

    {:ok, tmp_md_dir: tmp_md_dir, tmp_lib_dir: tmp_lib_dir, tmp_mig_dir: tmp_mig_dir}
  end

  test "LRP Modernization Flow: md-only tasarım üretimi ve Elixir koda yükseltme", context do
    # 1. Onboarding Wizard/Tasarım girdileri
    design_opts = %{
      output_dir: context.tmp_md_dir,
      capabilities: [
        %{
          type: "billing",
          description: "Müşteri fatura oluşturma ve gönderme yeteneği",
          interface_contract: %{
            "create_invoice/2" => "fatura oluşturur ve objeyi kaydeder",
            "cancel_invoice/1" => "faturayı iptal eder"
          },
          providers: [
            %{type: "internal_md", description: "İlk blueprint tasarım", upgrade_to: "elixir_module"}
          ]
        }
      ]
    }

    # 2. Level 1: md-only blueprint dosyalarını üret
    assert {:ok, generated_mds} = MdOnly.generate_all(design_opts)
    
    # 3. Dosyaların yazıldığını doğrula
    assert Enum.any?(generated_mds, &String.contains?(&1, "README.md"))
    assert Enum.any?(generated_mds, &String.contains?(&1, "billing.md"))
    assert Enum.any?(generated_mds, &String.contains?(&1, "billing-internal_md.md"))

    # 4. Level 2: md-only tasarım belgelerini Elixir koduna yükselt (Upgrade)
    assert {:ok, generated_elixirs} = ElixirGenerator.upgrade_from_md(
      context.tmp_md_dir,
      lib_dir: context.tmp_lib_dir,
      mig_dir: context.tmp_mig_dir
    )

    # 5. Elixir dosyalarının (migration, schema, context) üretildiğini doğrula
    assert Enum.any?(generated_elixirs, &String.contains?(&1, "create_billing_capability.exs"))
    assert Enum.any?(generated_elixirs, &String.contains?(&1, "billing_schema.ex"))
    assert Enum.any?(generated_elixirs, &String.contains?(&1, "billing_context.ex"))

    # Dosya içeriklerini kontrol et
    [mig_file] = Enum.filter(generated_elixirs, &String.contains?(&1, "create_billing_capability.exs"))
    mig_content = File.read!(mig_file)
    assert mig_content =~ "defmodule LRP.Repo.Migrations.CreateBillingCapability"
    assert mig_content =~ "create table(:billing_records"

    [schema_file] = Enum.filter(generated_elixirs, &String.contains?(&1, "billing_schema.ex"))
    schema_content = File.read!(schema_file)
    assert schema_content =~ "defmodule LRP.BillingSchema"
    assert schema_content =~ "schema \"billing_records\""

    [context_file] = Enum.filter(generated_elixirs, &String.contains?(&1, "billing_context.ex"))
    context_content = File.read!(context_file)
    assert context_content =~ "defmodule LRP.Billing"
    assert context_content =~ "def create(attrs)"
  end
end
