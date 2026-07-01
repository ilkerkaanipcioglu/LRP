defmodule LRP.AnalyzerTest do
  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Analyzer Test Tenant"})
    
    # Testler için geçici dizin oluştur
    tmp_dir = Path.join([File.cwd!(), "tmp", "test_project"])
    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join(File.cwd!(), "tmp"))
    end)

    {:ok, tenant: tenant, tmp_dir: tmp_dir}
  end

  test "Elixir projesi analiz edilir, LRP Graph ve PROCESS_TASK'lar oluşturulur", %{tenant: tenant, tmp_dir: tmp_dir} do
    # 1. Mock Elixir dosyaları yaz
    elixir_file = """
    defmodule MyProject.OrderService do
      @moduledoc "Handles customer orders."
      use Ecto.Schema
      alias MyProject.PaymentService

      def create_order(user_id, params) do
        # Emits event
        LRP.log_event(%{event_type: "order_created", idempotency_key: "abc"})
        :ok
      end
    end
    """
    File.write!(Path.join(tmp_dir, "order_service.ex"), elixir_file)

    # 2. Analiz et
    assert {:ok, result} = LRP.Analyzer.analyze(tmp_dir, tenant_id: tenant.id)

    assert result.language == "Elixir"
    assert result.stats.files == 1
    assert result.stats.modules == 1
    
    [mod_obj] = result.modules
    assert mod_obj.name == "MyProject.OrderService"
    assert mod_obj.metadata["line_count"] in [11, 12]
    assert mod_obj.metadata["moduledoc"] == "Handles customer orders."
    assert "create_order/2" in mod_obj.metadata["functions"]

    # 3. Skorlama doğrula
    assert result.score.total > 0.0
  end

  test "Python projesi analiz edilir ve LRP Graph oluşturulur", %{tenant: tenant, tmp_dir: tmp_dir} do
    # 1. Mock Python dosyaları yaz
    python_file = """
    \"\"\"
    Python Order Processing Module.
    \"\"\"
    import payment_service
    from user_module import get_user

    class OrderProcessor:
        def process_order(self, order_id, user_id):
            print("Processing")
            return True
    """
    File.write!(Path.join(tmp_dir, "order.py"), python_file)

    # 2. Analiz et
    assert {:ok, result} = LRP.Analyzer.analyze(tmp_dir, tenant_id: tenant.id)

    assert result.language == "Python"
    assert result.stats.files == 1
    assert result.stats.modules == 1

    [class_obj] = result.modules
    assert class_obj.name == "OrderProcessor"
    assert "payment_service" in class_obj.metadata["aliases"]
    assert "process_order/3" in class_obj.metadata["functions"]
  end
end
