### Typing parameters and return values

* __Category:__ Erlang-specific Refactorings.

* __Note:__ Formerly known as "Generate function specification".

* __Motivation:__ Despite being a dynamically-typed language, Elixir offers a feature to compensate for the lack of a static type system. By using ``Typespecs``, we can specify the types of each function parameter and of the return value. Utilizing this Elixir feature not only improves documentation, but also can enhance code readability and prepare it to be analyzed for tools like [Dialyzer][Dialyzer], enabling the detection of type inconsistencies, and potential bugs. The goal of this refactoring is simply to use ``Typespecs`` in a function to promote the aforementioned benefits of using this feature.

* __Examples:__ The following code has already been presented in another context in the refactoring [Extract expressions](#extract-expressions). Prior to the refactoring, we have a module ``Bhaskara`` composed of the function ``solve/3``, responsible for finding the roots of a quadratic equation. Note that this function should receive three real numbers as parameters and return a tuple of two elements. The first element of this tuple is always an atom, while the second element may be a String (if there are no roots) or a tuple containing the two roots of the quadratic equation.

  ```elixir
  # Before refactoring:

  defmodule Bhaskara do
    
    def solve(a, b, c) do
      delta = (b*b - 4*a*c)

      if delta < 0 do
        {:error, "No real roots"}
      else
        x1 = (-b + delta ** 0.5) / (2*a)
        x2 = (-b - delta ** 0.5) / (2*a)
        {:ok, {x1, x2}}
      end
    end

  end

  #...Use examples...
  iex(1)> Bhaskara.solve(1, 3, -4) 
  {:ok, {1.0, -4.0}}

  iex(2)> Bhaskara.solve(1, 2, 3)
  {:error, "No real roots"}
  ```

  To easier this code understanding and leverage the other aforementioned benefits, we can generate a function specification using the ``@spec`` module attribute which is a default feature of Elixir. This module attribute should be placed immediately before the function definition, following the pattern ``@spec function_name(arg_type, arg_type...) :: return_type``.

  ```elixir
  # After refactoring:

  defmodule Bhaskara do
    
    @spec solve(number, number, number) :: {atom, String.t() | {number, number}}
    def solve(a, b, c) do
      delta = (b*b - 4*a*c)

      if delta < 0 do
        {:error, "No real roots"}
      else
        x1 = (-b + delta ** 0.5) / (2*a)
        x2 = (-b - delta ** 0.5) / (2*a)
        {:ok, {x1, x2}}
      end
    end

  end

  #...Retrieving code documentation...
  iex(1)> h Bhaskara.solve/3
                             
  @spec solve(number(), number(), number()) ::
          {atom(), String.t() | {number(), number()}}
  ```

  Note that with the use of ``@spec``, we can easily check the function specification using Elixir's helper.

* __Side-conditions:__
  * This refactoring is free from any preconditions or postconditions, and can therefore always be used to improve the specification of any named function.
