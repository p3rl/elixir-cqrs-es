defmodule Uuid do
  def new, do: Kernel.make_ref()
end

defmodule EventStore do
  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def commit(event_records) do
    Agent.update(__MODULE__, fn (history) ->
      Enum.concat(history, event_records)
    end)
  end

  def history(uuid) do
    Agent.get(__MODULE__, fn (event_records) ->
      Enum.filter(event_records, fn e -> e.source_id == uuid end)
      end)
  end
end

defmodule Activity do
  defstruct id: -1, name: "", type: "", state: nil
end

defmodule Workflow do
  defstruct id: nil, version: 0, events: [], activities: []

  def new do
    apply_event(%Workflow{}, %{eventType: :workflow_created, workflowId: Uuid.new})
  end

  def from_history(event_records) do
    Enum.reduce(event_records, %Workflow{}, &handle_event(&2, &1.event))
  end

  def create_activity(workflow, name, type) do
    nextId = 1 + length(workflow.activities)
    apply_event(workflow, %{event_type: :activity_created, id: nextId, name: name, type: type})
  end

  defp apply_event(workflow, event) do
    handle_event(workflow, event) |> append_event event
  end

  defp append_event(workflow, event) do
    version = 1 + workflow.version
    event_record = %{source_id: workflow.id, version: version, event: event}
    %Workflow{workflow | version: version, events: [event_record | workflow.events]}
  end

  defp handle_event(workflow, %{eventType: :workflow_created, workflowId: id}) do
    %Workflow{workflow | id: id}
  end

  defp handle_event(workflow, %{event_type: :activity_created, id: id, name: name, type: type}) do
    activity = %Activity{id: id, name: name, type: type, state: :activity_state_created}
    %Workflow{workflow | activities: [activity | workflow.activities]}
  end
end
