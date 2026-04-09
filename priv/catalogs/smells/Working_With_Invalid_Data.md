### Working with invalid data

* __Category:__ Low-level concerns smells.

* __Problem:__ This code smell refers to a function that does not validate its parameters' types and therefore can produce internal non-predicted behavior. When an error is raised inside a function due to an invalid parameter value, this can confuse the developers and make it harder to locate and fix the error.

* __Example:__ An example of this code smell is when a function receives an invalid parameter and then passes it to a function from a third-party library. This will cause an error (raised deep inside the library function), which may be confusing for the developer who is working with invalid data. As shown next, the function ``foo/1`` is a client of a third-party library and doesn't validate its parameters at the boundary. In this way, it is possible that invalid data will be passed from ``foo/1`` to the library, causing a mysterious error.

  ```elixir
  defmodule MyApp do
    alias ThirdPartyLibrary, as: Library

    def foo(invalid_data) do
      #...some code...
      Library.sum(1, invalid_data)
      #...some code...
    end
  end

  #...Use examples...

  # with valid data is ok
  iex(1)> MyApp.foo(2)
  3

  #with invalid data cause a confusing error deep inside
  iex(2)> MyApp.foo("Lucas")
  ** (ArithmeticError) bad argument in arithmetic expression: 1 + "Lucas"
    :erlang.+(1, "Lucas")
    library.ex:3: ThirdPartyLibrary.sum/2
  ```

* __Refactoring:__ To remove this code smell, client code must validate input parameters at the boundary with the user, via guard clauses or pattern matching. This will prevent errors from occurring deeply, making them easier to understand. This refactoring will also allow libraries to be implemented without worrying about creating internal protection mechanisms. The next code illustrates the refactoring of ``foo/1``, removing this smell:

  ```elixir
  defmodule MyApp do
    alias ThirdPartyLibrary, as: Library

    def foo(data) when is_integer(data) do
      #...some code...
      Library.sum(1, data)
      #...some code...
    end
  end

  #...Use examples...

  #with valid data is ok
  iex(1)> MyApp.foo(2)
  3

  # with invalid data errors are easy to locate and fix
  iex(2)> MyApp.foo("Lucas")
  ** (FunctionClauseError) no function clause matching in MyApp.foo/1

    The following arguments were given to MyApp.foo/1:

        # 1
        "Lucas"

    my_app.ex:6: MyApp.foo/1
  ```

  This example is based on code provided in Elixir's official documentation. Source: [link][WorkingWithInvalidDataExample]

* __Treatments:__

  * [Typing parameters and return values](https://github.com/lucasvegi/Elixir-Refactorings?#typing-parameters-and-return-values) |> [Add type declarations and contracts](https://github.com/lucasvegi/Elixir-Refactorings?#add-type-declarations-and-contracts)
  * [Introduce pattern matching over a parameter](https://github.com/lucasvegi/Elixir-Refactorings?#introduce-pattern-matching-over-a-parameter)
  * [Struct guard to matching](https://github.com/lucasvegi/Elixir-Refactorings?#struct-guard-to-matching)
  * [Simplifying guard sequences](https://github.com/lucasvegi/Elixir-Refactorings?#simplifying-guard-sequences)
  * [Converts guards to conditionals](https://github.com/lucasvegi/Elixir-Refactorings?#converts-guards-to-conditionals)
