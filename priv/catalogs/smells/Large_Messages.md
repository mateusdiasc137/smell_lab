### Large messages

* __Category:__ Design-related smell.

* __Note:__ Formerly known as "Large messages between processes".

* __Problem:__ In Elixir, processes run in an isolated manner, often concurrently with other. Communication between different processes is performed via message passing. The exchange of messages between processes is not a code smell in itself; however, when processes exchange messages, their contents are copied between them. For this reason, if a huge structure is sent as a message from one process to another, the sender can become blocked, compromising performance. If these large message exchanges occur frequently, the prolonged and frequent blocking of processes can cause a system to behave anomalously.

* __Example:__ The following code is composed of two modules which will each run in a different process. As the names suggest, the ``Sender`` module has a function responsible for sending messages from one process to another (i.e., ``send_msg/3``). The ``Receiver`` module has a function to create a process to receive messages (i.e., ``create/0``) and another one to handle the received messages (i.e., ``run/0``). If a huge structure, such as a list with 1_000_000 different values, is sent frequently from ``Sender`` to ``Receiver``, the impacts of this smell could be felt.

  ```elixir
  defmodule Receiver do
    @doc """
      Function for receiving messages from processes.
    """
    def run do
      receive do
        {:msg, msg_received} -> msg_received
        {_, _} -> "won't match"
      end
    end

    @doc """
      Create a process to receive a message.
      Messages are received in the run() function of Receiver.
    """
    def create do
      spawn(Receiver, :run, [])
    end
  end
  ```

  ```elixir
  defmodule Sender do
    @doc """
      Function for sending messages between processes.
        pid_receiver: message recipient.
        msg: messages of any type and size can be sent.
        id_msg: used by receiver to decide what to do
                when a message arrives.
                Default is the atom :msg
    """
    def send_msg(pid_receiver, msg, id_msg \\ :msg) do
      send(pid_receiver, {id_msg, msg})
    end
  end
  ```

  Examples of large messages between processes:

  ```elixir
  iex(1)> pid = Receiver.create
  #PID<0.144.0>

  #Simulating a message with large content - List with length 1_000_000
  iex(2)> msg = %{from: inspect(self()), to: inspect(pid), content: Enum.to_list(1..1_000_000)}

  iex(3)> Sender.send_msg(pid, msg)
  {:msg,
    %{
      content: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
        20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
        39, 40, 41, 42, 43, 44, 45, 46, 47, ...],
      from: "#PID<0.105.0>",
      to: "#PID<0.144.0>"
    }}
  ```

  This example is based on a original code by Samuel Mullen. Source: [link][LargeMessageExample]

* __Treatments:__

  * [Defining a subset of a Map](https://github.com/lucasvegi/Elixir-Refactorings?#defining-a-subset-of-a-map)
  * [Extract expressions](https://github.com/lucasvegi/Elixir-Refactorings?#extract-expressions)
  * [Add a tag to messages](https://github.com/lucasvegi/Elixir-Refactorings?#add-a-tag-to-messages)
