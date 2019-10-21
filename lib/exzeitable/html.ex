defmodule Exzeitable.HTML do
  @moduledoc """
    For building the HTML tags themselves, check CSS.md for information on applying CSS classes.
  """

  use Phoenix.HTML
  alias Exzeitable.{Filter, Format}

  @doc "Root function for building the HTML table"
  @spec build_table(map) :: {:safe, iolist}
  def build_table(assigns) do
    assigns
    |> head_section()
    |> body_section(assigns)
    |> cont(:table, class: "exz-table")
    |> maybe_nothing_found(assigns)
    |> cont(:div, class: "exz-table-wrapper")
    |> build_outer(assigns)
  end

  @spec head_section(map) :: {:safe, iolist}
  defp head_section(assigns) do
    assigns
    |> Map.get(:fields)
    |> Filter.fields_where_not(:hidden)
    |> add_actions_header(assigns)
    |> Enum.map(fn column -> table_header(column, assigns) end)
    |> cont(:thead, [])
  end

  @spec add_actions_header(keyword, map) :: keyword
  defp add_actions_header(fields, %{action_buttons: []}), do: fields

  defp add_actions_header(fields, _assigns) do
    fields ++ [actions: %{sort: false, search: false, order: false}]
  end

  @spec body_section({:safe, iolist | binary}, map) :: [{:safe, iolist}]
  defp body_section(head_section, %{list: list} = assigns) do
    body =
      list
      |> Enum.map(fn entry -> build_row(entry, assigns) end)
      |> cont(:tbody, [])

    [head_section, body]
  end

  # onclick="" is for iOS support
  @spec build_outer({:safe, iolist}, map) :: {:safe, iolist}
  defp build_outer(contents, assigns) do
    search_box = build_search(assigns)
    new_button = build_action_button(:new, assigns)
    show_buttons = show_buttons(assigns)
    pagination = build_pagination(assigns)
    show_hide_fields = build_show_hide_fields_button(assigns)

    top_navigation =
      [
        [pagination, new_button, show_hide_fields] |> cont(:div, class: "exz-pagination-wrapper"),
        search_box
      ]
      |> cont(:div, class: "exz-row")

    bottom_buttons = [new_button, show_hide_fields] |> cont(:div, [])

    [
      top_navigation,
      show_buttons,
      contents,
      show_buttons,
      bottom_buttons,
      pagination
    ]
    |> cont(:div, class: "outer-wrapper", onclick: "")
  end

  @spec build_search(map) :: {:safe, iolist}
  defp build_search(%{debounce: debounce} = assigns) do
    if Filter.search_enabled?(assigns) do
      form_for(
        :search,
        "#",
        # onkeypress to disable enter key in search field
        [
          phx_change: :search,
          class: "exz-search-form",
          onkeypress: "return event.keyCode != 13;"
        ],
        fn f ->
          [
            text_input(f, :search,
              placeholder: "Search",
              class: "exz-search-field",
              phx_debounce: debounce
            ),
            counter(assigns)
          ]
          |> cont(:div, class: "exz-search-field-wrapper")
        end
      )
      |> cont(:div, class: "exz-search-wrapper")
    else
      ""
    end
  end

  defp counter(%{count: count}) do
    cont(count, :span, class: "exz-counter-field")
    |> cont(:div, class: "exz-counter-field-wrapper")
  end

  @spec table_header({atom, map}, map) :: {:safe, iolist}
  defp table_header(field, assigns) do
    [Format.header(field), hide_link_for(field), sort_link_for(field, assigns)]
    |> cont(:th, [])
  end

  @spec build_row(atom, map) :: {:safe, iolist}
  defp build_row(entry, assigns) do
    values =
      assigns
      |> Map.get(:fields)
      |> Filter.fields_where_not(:hidden)
      |> Keyword.keys()
      |> Enum.map(fn key -> Format.field(entry, key, assigns) end)
      |> Enum.map(fn value -> cont(value, :td, []) end)

    [values | build_actions(entry, assigns)]
    |> cont(:tr, [])
  end

  @spec build_actions(atom, map) :: {:safe, iolist}
  defp build_actions(_entry, %{action_buttons: []}), do: ""

  defp build_actions(entry, assigns) do
    assigns
    |> Map.get(:action_buttons)
    |> Kernel.--([:new])
    |> Enum.map(fn action -> build_action_button(action, entry, assigns) end)
    |> cont(:td, [])
  end

  @spec build_pagination(map) :: {:safe, iolist}
  defp build_pagination(%{page: page} = assigns) do
    pages = page_count(assigns)

    ([paginate_button("Previous", page, pages)] ++
       numbered_buttons(page, pages) ++
       [paginate_button("Next", page, pages)])
    |> cont(:ul, class: "exz-pagination-ul")
    |> cont(:nav, class: "exz-pagination-nav")
  end

  @spec numbered_buttons(integer, integer) :: [{:safe, iolist}]
  defp numbered_buttons(_page, 0) do
    [paginate_button(1, 1, 1)]
  end

  defp numbered_buttons(page, pages) do
    pages
    |> Filter.filter_pages(page)
    |> Enum.map(fn x -> paginate_button(x, page, pages) end)
  end

  defp page_count(%{count: count, per_page: per_page}) do
    if rem(count, per_page) > 0 do
      div(count, per_page) + 1
    else
      div(count, per_page)
    end
  end

  defp maybe_nothing_found(content, %{list: []}) do
    nothing_found =
      "Nothing Found"
      |> cont(:div, class: "exz-nothing-found")

    [content, nothing_found]
  end

  defp maybe_nothing_found(content, _assigns) do
    content
  end

  # Used everywhere to make it easier to pipe HTML chunks into each other
  @spec cont(any(), atom, keyword) :: {:safe, iolist}
  defp cont(body, tag, opts), do: content_tag(tag, body, opts)

  ###########################
  ######### BUTTONS #########
  ###########################

  @spec paginate_button(String.t() | integer, integer, integer) :: {:safe, iolist}
  defp paginate_button("Next", page, pages) when page == pages do
    cont("Next", :a, class: "exz-pagination-a", tabindex: "-1")
    |> cont(:li, class: "exz-pagination-li-disabled")
  end

  defp paginate_button("Previous", 1, _pages) do
    cont("Previous", :a, class: "exz-pagination-a", tabindex: "-1")
    |> cont(:li, class: "exz-pagination-li-disabled")
  end

  defp paginate_button("....", _page, _pages) do
    cont("....", :a, class: "exz-pagination-a exz-pagination-width", tabindex: "-1")
    |> cont(:li, class: "exz-pagination-li-disabled")
  end

  defp paginate_button("Next", page, _pages) do
    cont("Next", :a,
      class: "exz-pagination-a",
      style: "cursor: pointer",
      "phx-click": "change_page",
      "phx-value-page": page + 1
    )
    |> cont(:li, class: "exz-pagination-li")
  end

  defp paginate_button("Previous", page, _pages) do
    cont("Previous", :a,
      class: "exz-pagination-a",
      style: "cursor: pointer",
      "phx-click": "change_page",
      "phx-value-page": page - 1
    )
    |> cont(:li, class: "exz-pagination-li")
  end

  defp paginate_button(same, same, _pages) do
    cont(same, :a, class: "exz-pagination-a exz-pagination-width")
    |> cont(:li, class: "exz-pagination-li-active")
  end

  defp paginate_button(label, _page, _pages) do
    cont(label, :a,
      class: "exz-pagination-a exz-pagination-width",
      style: "cursor: pointer",
      "phx-click": "change_page",
      "phx-value-page": label
    )
    |> cont(:li, class: "exz-pagination-li")
  end

  @spec hide_link_for({atom, map}) :: {:safe, iolist}
  defp hide_link_for({:actions, _value}), do: ""

  defp hide_link_for({key, _value}) do
    cont("hide", :a,
      class: "exz-hide-link",
      "phx-click": "hide_column",
      "phx-value-column": key
    )
  end

  @spec sort_link_for({atom, map}, map) :: {:safe, iolist}
  defp sort_link_for({:actions, _v}, _), do: ""
  defp sort_link_for({_key, %{order: false}}, _), do: ""

  defp sort_link_for({key, _v}, %{order: order}) do
    label =
      case order do
        [desc: ^key] -> "sort ▲"
        [asc: ^key] -> "sort ▼"
        _ -> "sort  "
      end

    cont(label, :a,
      class: "exz-sort-link",
      "phx-click": "sort_column",
      "phx-value-column": key
    )
  end

  @spec show_buttons(map) :: [any()]
  defp show_buttons(%{show_field_buttons: false}), do: ""

  defp show_buttons(assigns) do
    assigns
    |> Map.get(:fields)
    |> Filter.fields_where(:hidden)
    |> Enum.map(fn field -> build_show_button(field) end)
  end

  defp build_show_button({key, _value} = field) do
    name = Format.header(field)

    "Show #{name}"
    |> cont(:a,
      class: "exz-show-button",
      "phx-click": "show_column",
      "phx-value-column": key
    )
  end

  # New, create, show etc.
  @spec build_action_button(atom, atom, map) :: {:safe, iolist}
  defp build_action_button(:new, %{parent: nil} = assigns) do
    %{
      csrf_token: csrf_token,
      socket: socket,
      routes: routes,
      path: path,
      action_buttons: action_buttons
    } = assigns

    if Enum.member?(action_buttons, :new) do
      apply(routes, path, [socket, :new])
      |> html_button(:new, csrf_token)
    else
      ""
    end
  end

  defp build_action_button(:new, %{parent: parent} = assigns) do
    %{
      csrf_token: csrf_token,
      socket: socket,
      routes: routes,
      path: path,
      action_buttons: action_buttons
    } = assigns

    if Enum.member?(action_buttons, :new) do
      apply(routes, path, [socket, :new, parent])
      |> html_button(:new, csrf_token)
    else
      ""
    end
  end

  defp build_action_button(:delete, entry, %{belongs_to: nil} = assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns

    apply(routes, path, [socket, :delete, entry])
    |> html_button(:delete, csrf_token)
  end

  defp build_action_button(:delete, entry, assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns

    params = [socket, :delete, Filter.parent_for(entry, assigns), entry]

    apply(routes, path, params)
    |> html_button(:delete, csrf_token)
  end

  defp build_action_button(:show, entry, %{belongs_to: nil} = assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns

    apply(routes, path, [socket, :show, entry])
    |> html_button(:show, csrf_token)
  end

  defp build_action_button(:show, entry, assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns

    params = [socket, :show, Filter.parent_for(entry, assigns), entry]

    apply(routes, path, params)
    |> html_button(:show, csrf_token)
  end

  defp build_action_button(:edit, entry, %{belongs_to: nil} = assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns

    apply(routes, path, [socket, :edit, entry])
    |> html_button(:edit, csrf_token)
  end

  defp build_action_button(:edit, entry, assigns) do
    %{csrf_token: csrf_token, socket: socket, routes: routes, path: path} = assigns
    params = [socket, :edit, Filter.parent_for(entry, assigns), entry]

    apply(routes, path, params)
    |> html_button(:edit, csrf_token)
  end

  @spec html_button(String.t(), atom, String.t()) :: {:safe, iolist}
  defp html_button(route, :new, _csrf_token), do: link("New", to: route, class: "exz-action-new")

  defp html_button(route, :show, _csrf_token),
    do: link("Show", to: route, class: "exz-action-show")

  defp html_button(route, :edit, _csrf_token),
    do: link("Edit", to: route, class: "exz-action-edit")

  defp html_button(route, :delete, csrf_token) do
    link("Delete",
      to: route,
      class: "exz-action-delete",
      method: :delete,
      "data-confirm": "Are you sure?",
      csrf_token: csrf_token
    )
  end

  defp build_show_hide_fields_button(%{show_field_buttons: show_field_buttons}) do
    {name, value} =
      if show_field_buttons do
        {"Hide Field Buttons", "hide_buttons"}
      else
        {"Show Field Buttons", "show_buttons"}
      end

    name
    |> cont(:a,
      class: "exz-info-button",
      "phx-click": value
    )
  end
end
