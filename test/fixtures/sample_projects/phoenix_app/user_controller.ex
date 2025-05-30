defmodule FixtureApp.UserController do
  use Phoenix.Controller
  
  alias FixtureApp.{User, Repo}
  
  def index(conn, _params) do
    users = Repo.all(User)
    render(conn, "index.html", users: users)
  end
  
  def show(conn, %{"id" => id}) do
    user = Repo.get!(User, id)
    render(conn, "show.html", user: user)
  end
  
  def create(conn, %{"user" => user_params}) do
    case User.create_changeset(user_params) |> Repo.insert() do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully")
        |> redirect(to: user_path(conn, :show, user))
      
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
