### Add type declarations and contracts

* __Category:__ Erlang-specific Refactorings.

* __Motivation:__ Despite being a dynamically-typed language, Elixir offers a feature to compensate for the lack of a static type system. By using ``Typespecs``, we can specify the types of each function parameter and of the return value. Utilizing this Elixir feature not only improves documentation, but also can enhance code readability and prepare it to be analyzed for tools like [Dialyzer][Dialyzer], enabling the detection of type inconsistencies, and potential bugs. The goal of this refactoring is to use `Typespecs` to create custom data types, thereby naming recurring data structures in the codebase and increasing system readability.

* __Examples:__ The following code examples illustrate this refactoring. Prior to refactoring, we have a function ``set_background/1`` that receives a tuple of three integer elements. This function performs some processing with this tuple and returns an atom. The function interface for ``set_background/1`` is defined in the module attribute ``@spec``.

  ```elixir
  # Before refactoring:

  defmodule Foo do

    @spec set_background({integer, integer, integer}) :: atom
    def set_background(rgb) do
      #do something...
      :ok
    end
  end

  #...Use examples...
  iex(1)> Foo.set_background({150, 25, 89})
  :ok
  ```

  To easier this code understanding and leverage the other aforementioned benefits, we can generate a type specification using the ``@type`` module attribute which is a default feature of Elixir.

  ```elixir
  # After refactoring:

  defmodule Foo do

    @typedoc """
      A tuple with three integer elements between 0..255
    """
    @type color :: {red :: integer, green :: integer, blue :: integer}

    @spec set_background(color) :: atom
    def set_background(rgb) do
      #do something...
      :ok
    end
  end

  #...Use examples...
  iex(1)> Foo.set_background({150, 25, 89})
  :ok

  #...Retrieving code documentation...
  iex(2)> h Foo.set_background/1                           
  @spec set_background(color()) :: atom()

  iex(3)> t Foo.color   #<= type documentation!
  @type color() :: {red :: integer(), green :: integer(), blue :: integer()}

  A tuple with three integer elements between 0..255
  ```

  Note that with the use of ``@type``, we can easily check the type specification using Elixir's helper.

* __Side-conditions:__
  * The name of the type created by this refactoring (*e.g.*, `color()`) must be unique. In other words, it must be different from all predefined basic types in Elixir (*e.g.*, `integer()`, `float()`, `atom()`, etc.), as well as from all custom data types defined in the refactored module or any other module in the codebase, including those from imported external libraries.

  * Although type names and function names do not technically conflict, having a type with the same name as a function defined in the module can cause confusion for code readers. Therefore, it is a good practice to ensure that type names are unique, even in relation to function names. For this reason, this is also a side condition of this refactoring.
