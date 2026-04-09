defmodule SmellLabWeb.PageController do
  use SmellLabWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
