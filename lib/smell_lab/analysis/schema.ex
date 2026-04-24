defmodule SmellLab.Analysis.Schemas do
  def smell_detection_schema do
    [
      has_smell: [type: :boolean, required: true],
      smell_id: [type: :string, required: true],
      smell_name: [type: :string, required: true],
      explanation: [type: :string, required: true],
      confidence: [type: :string, required: true],
      start_line: [type: :integer, required: true],
      end_line: [type: :integer, required: true]
    ]
  end

  def refactor_schema do
    [
      refactored_code: [type: :string, required: true]
    ]
  end
end
