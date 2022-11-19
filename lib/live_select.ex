defmodule LiveSelect do
  alias LiveSelect.ChangeMsg
  import Phoenix.Component
  # for backward compatibility with LiveView 0.17
  # generates compile warning if run with LiveView 0.18
  import Phoenix.LiveView.Helpers

  @moduledoc ~S"""
  The `LiveSelect` field is rendered by calling the `live_select/3` function and passing it a form and the name of the field.
  LiveSelect creates a text input field in which the user can type text, and a hidden input field that will contain the value of the selected option.
  As the text changes, LiveSelect will render a dropdown below the text input
  containing the matching options, which the user can then select.

  Selection can happen either using the keyboard, by navigating the options with the arrow keys and then pressing enter, or by
  clicking an option with the mouse.
    
  Whenever an option is selected, `LiveSelect` will trigger a standard `phx-change` event in the form. See the "Examples" section
  below for details on how to handle the event.

  After an option has been selected, the selection can be undone by clicking on text field.

  <img alt="demo" src="https://raw.githubusercontent.com/maxmarcon/live_select/main/priv/static/images/demo.gif" width="300" />
     
  ## Reacting to user's input

  Whenever the user types something in the text input, LiveSelect sends a `t:LiveSelect.ChangeMsg.t/0` message to your LiveView.
  The message has a `text` property containing the current text entered by the user, and a `field` property with the name of the LiveSelect field.
  The LiveView's job is to [`handle_info/2`](`c:Phoenix.LiveView.handle_info/2`) the message and then call `update_options/2`
  to update the dropdown's content with the new set of selectable options. See the "Examples" section below for details.

  ## Examples

  Here's an example that describes all the moving parts in detail. The user can search for cities.
  The LiveSelect main form input is called `city_search`.
  When a city is selected, the coordinates of that city will be the value of the form input.
  The name of the selected city is available in the text input field named `city_search_text_input`.
    
  Template:
  ```
  <.form for={:my_form} :let={f} phx-change="change">
      <%= live_select f, :city_search %> 
  </.form>
  ```

  LiveView:
  ```
  import LiveSelect

  @impl true
  def handle_info(%LiveSelect.ChangeMsg{} = change_msg, socket) do 
    cities = City.search(change_msg.text)
    # cities could be:
    # [ {"city name 1", [lat_1, long_1]}, {"city name 2", [lat_2, long_2]}, ... ]
    #
    # but it could also be (no coordinates in this case):
    # [ "city name 1", "city name 2", ... ]
    #
    # or:
    # [ [label: "city name 1", value: [lat_1, long_1]], [label: "city name 2", value: [lat_2, long_2]], ... ] 
    #
    # or even:
    # ["city name 1": [lat_1, long_1], "city name 2": [lat_2, long_2]]

    update_options(change_msg, cities)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "change",
        %{"my_form" => %{"city_search_text_input" => city_name, "city_search" => city_coords}},
        socket
      ) do
    IO.puts("You selected city #{city_name} located at: #{city_coords}")

    {:noreply, socket}
  end  
  ```

  ### Multiple LiveSelect inputs in the same LiveView  
    
  If you have multiple LiveSelect inputs in the same LiveView, you can distinguish them based on the field. 
  For example:

  Template:
  ```
  <.form for={:my_form} :let={f} phx-change="change">
      <%= live_select f, :city_search %> 
      <%= live_select f, :album_search %>
  </.form>
  ```

  LiveView:
  ```
  @impl true
  def handle_info(%LiveSelect.ChangeMsg{} = change_msg, socket) do
    options =
      case change_msg.field do
        :city_search -> City.search(change_msg.text)
        :album_search -> Album.search(change_msg.text)
      end

    update_options(change_msg, options)

    {:noreply, socket}
  end
  ```
  """

  @doc ~S"""
  Renders a `LiveSelect` input in a `form` with a given `field` name.

  LiveSelect renders two inputs: a hidden input named `field` that holds the value of the selected option, 
  and a visible text input field named `#{field}_text_input` that contains the text entered by the user.
    
  **Opts:**

  * `disabled` - set this to a truthy value to disable the input field
  * `placeholder` - placeholder text for the input field  
  * `debounce` - number of milliseconds to wait after the last keystroke before sending a `t:LiveSelect.ChangeMsg.t/0` message. Defaults to 100ms
  * `update_min_len` - the minimum length of text in the text input field that will trigger an update of the dropdown. It has to be a positive integer. Defaults to 3
  * `style` - one of `:tailwind` (the default), `:daisyui` or `:none`. See the [Styling section](styling.html) for details
  * `active_option_class`, `container_class`, `container_extra_class`, `dropdown_class`, `dropdown_extra_class`, `option_class`, `option_extra_class`, `text_input_class`, `text_input_extra_class`, `text_input_selected_class` - see the [Styling section](styling.html) for details
    
  """
  def live_select(form, field, opts \\ [])
      when (is_binary(field) or is_atom(field)) and is_list(opts) do
    form_name = if is_struct(form, Phoenix.HTML.Form), do: form.name, else: to_string(form)

    assigns =
      opts
      |> Map.new()
      |> Map.put(:id, "#{form_name}_#{field}_component")
      |> Map.put(:module, LiveSelect.Component)
      # Ecto forms expect atom fields:
      # https://github.com/phoenixframework/phoenix_ecto/blob/master/lib/phoenix_ecto/html.ex#L123
      |> Map.put(:field, String.to_atom("#{field}"))
      |> Map.put(:form, form)

    ~H"""
    <.live_component {assigns} />
    """
  end

  @doc ~S"""
  Updates a `LiveSelect` component with new options. `change_msg` must be the `t:LiveSelect.ChangeMsg.t/0` originally sent by the LiveSelect,
  and `options` is the new list of options that will be used to fill the dropdown.

  Each option will be assigned a label, which will be shown in the dropdown, and a value, which will be the value of the
  LiveSelect input when the option is selected.
   
  `options` can be any enumerable of the following elements:

  * _atoms, strings or numbers_: In this case, each element will be both label and value for the option
  * _tuples_: `{label, value}` corresponding to label and value for the option
  * _maps_: `%{label: label, value: value}`
  * _keywords_: `[label: label, value: value]`

  This means you can use maps and keyword lists to pass the list of options, for example:

  ```
  %{Red: 1, Yellow: 2, Green: 3}
  ```

  Will result in 3 options with labels `:Red`, `:Yellow`, `:Green` and values 1, 2, and 3.

  Note that the option values, if they are not strings, will be JSON-encoded. Your LiveView will receive this JSON-encoded version in the `phx-change` and `phx-submit` events.
  """
  def update_options(%ChangeMsg{} = change_msg, options) do
    Phoenix.LiveView.send_update(change_msg.module, id: change_msg.id, options: options)
  end
end
