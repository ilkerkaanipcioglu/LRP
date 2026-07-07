defmodule LRPWeb.ErrorHTML do
  use LRPWeb, :html

  def render_template(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule LRPWeb.ErrorJSON do
  use LRPWeb, :html

  def render_template(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
