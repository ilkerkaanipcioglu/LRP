defmodule LRPWeb.StudioLive.New do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    companies = LRP.list_companies()

    {:ok,
     socket
     |> assign(:companies, companies)
     |> assign(:form, %{"step" => 1, "name" => "", "db_url" => "", "company_id" => "", "desc" => ""})
     |> assign(:error, nil)
     |> assign(:created_project, nil)
     |> assign(:page_title, "New Project")
     |> assign(:active_nav, "film")}
  end

  @impl true
  def handle_event("update", %{"form" => params}, socket) do
    form = Map.merge(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("next", _params, socket) do
    form = socket.assigns.form
    step = form["step"] |> String.to_integer()

    case validate_step(step, form) do
      :ok ->
        {:noreply, assign(socket, :form, Map.put(form, "step", step + 1))}

      {:error, msg} ->
        {:noreply, assign(socket, :error, msg)}
    end
  end

  @impl true
  def handle_event("prev", _params, socket) do
    form = socket.assigns.form
    step = form["step"] |> String.to_integer()
    {:noreply, assign(socket, :form, Map.put(form, "step", step - 1))}
  end

  @impl true
  def handle_event("create", _params, socket) do
    form = socket.assigns.form

    company_result =
      if form["company_id"] != "" do
        {:ok, form["company_id"]}
      else
        case LRP.create_company(%{name: form["name"] <> " Company"}) do
          {:ok, company} -> {:ok, company.id}
          error -> error
        end
      end

    case company_result do
      {:ok, company_id} ->
        db_url = form["db_url"] || "sqlite:#{String.replace(form["name"], " ", "_")}_dev.db"

        case LRP.create_project(%{
               name: form["name"],
               database_url: db_url,
               company_id: company_id,
               metadata: %{"description" => form["desc"]}
             }) do
          {:ok, project} ->
            {:noreply, assign(socket, :created_project, project)}

          {:error, changeset} ->
            errors = format_changeset_errors(changeset)
            {:noreply, assign(socket, :error, errors)}
        end

      {:error, _} ->
        {:noreply, assign(socket, :error, "Company could not be created.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <a href="/studio" class="back-link">← Studio</a>
    </div>

    <%= if @created_project do %>
      <div class="card">
        <div class="card-empty" style="padding: 48px;">
          <div class="empty-icon">✅</div>
          <h3 style="font-size: 20px; color: var(--text-primary); margin-bottom: 8px;">Project Created!</h3>
          <p style="color: var(--text-secondary); margin-bottom: 24px;">
            <strong><%= @created_project.name %></strong> is ready.
          </p>
          <a href={"/studio/#{@created_project.id}"} class="btn">View Project</a>
        </div>
      </div>
    <% else %>
      <div class="wizard-container">
        <div class="wizard-steps">
          <div class={"wizard-step #{step_active(@form, 1)}"}>1. Basics</div>
          <div class="wizard-connector"></div>
          <div class={"wizard-step #{step_active(@form, 2)}"}>2. Database</div>
          <div class="wizard-connector"></div>
          <div class={"wizard-step #{step_active(@form, 3)}"}>3. Create</div>
        </div>

        <%= if @error do %>
          <div class="wizard-error"><%= @error %></div>
        <% end %>

        <div class="card" style="margin-top: 24px;">
          <div class="wizard-body">
            <%= render_step(assigns) %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_step(%{form: %{"step" => "1"}} = assigns) do
    ~H"""
    <h3 class="wizard-title">Project Basics</h3>
    <p class="wizard-desc">Name your project and optionally pick an existing company.</p>
    <form phx-change="update" phx-submit="next" class="wizard-form">
      <div class="form-group">
        <label class="form-label">Project Name</label>
        <input type="text" name="form[name]" value={@form["name"]} class="form-input" placeholder="e.g. ERP Modernization" required autofocus />
      </div>
      <div class="form-group">
        <label class="form-label">Description</label>
        <textarea name="form[desc]" class="form-textarea" placeholder="Brief project description..."><%= @form["desc"] %></textarea>
      </div>
      <div class="form-actions">
        <button type="submit" class="btn">Next →</button>
      </div>
    </form>
    """
  end

  defp render_step(%{form: %{"step" => "2"}} = assigns) do
    ~H"""
    <h3 class="wizard-title">Database Setup</h3>
    <p class="wizard-desc">Configure the database connection for this project.</p>
    <form phx-change="update" phx-submit="next" class="wizard-form">
      <div class="form-group">
        <label class="form-label">Database URL</label>
        <input type="text" name="form[db_url]" value={@form["db_url"]} class="form-input mono" placeholder="sqlite:./my_project_dev.db" />
        <span class="form-hint">Leave empty for default SQLite path.</span>
      </div>
      <div class="form-group">
        <label class="form-label">Company</label>
        <select name="form[company_id]" class="form-select">
          <option value="">-- Create New Company --</option>
          <%= for company <- @companies do %>
            <option value={company.id} selected={@form["company_id"] == company.id}><%= company.name %></option>
          <% end %>
        </select>
      </div>
      <div class="form-actions">
        <button type="button" phx-click="prev" class="btn btn-secondary">← Back</button>
        <button type="submit" class="btn">Next →</button>
      </div>
    </form>
    """
  end

  defp render_step(%{form: %{"step" => "3"}} = assigns) do
    ~H"""
    <h3 class="wizard-title">Review & Create</h3>
    <p class="wizard-desc">Confirm project details before creation.</p>
    <div class="review-card">
      <div class="review-row">
        <span class="review-label">Name</span>
        <span class="review-value"><%= @form["name"] %></span>
      </div>
      <div class="review-row">
        <span class="review-label">Description</span>
        <span class="review-value"><%= @form["desc"] || "(none)" %></span>
      </div>
      <div class="review-row">
        <span class="review-label">Database</span>
        <span class="review-value mono"><%= @form["db_url"] || "Default SQLite" %></span>
      </div>
      <div class="review-row">
        <span class="review-label">Company</span>
        <span class="review-value"><%= @form["company_id"] || "New (auto-created)" %></span>
      </div>
    </div>
    <div class="form-actions" style="margin-top: 24px;">
      <button type="button" phx-click="prev" class="btn btn-secondary">← Back</button>
      <button type="button" phx-click="create" class="btn">Create Project</button>
    </div>
    """
  end

  defp step_active(form, step) do
    current = String.to_integer(form["step"])
    cond do
      current == step -> "wizard-step--active"
      current > step -> "wizard-step--done"
      true -> "wizard-step--pending"
    end
  end

  defp validate_step(1, form) do
    if form["name"] == "" do
      {:error, "Project name is required."}
    else
      :ok
    end
  end
  defp validate_step(2, _form), do: :ok
  defp validate_step(3, _form), do: :ok

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
