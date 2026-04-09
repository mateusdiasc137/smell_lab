defmodule SmellLab.Analysis.Schemas do
  def smell_detection_schema do
    [
      has_smell: [type: :boolean, required: true],
      smell_name: [type: :string, required: true],
      explanation: [type: :string, required: true],
      confidence: [type: :string, required: true],
      start_line: [type: :integer, required: true],
      end_line: [type: :integer, required: true]
    ]
  end

  def refactor_schema do
    [
      summary: [type: :string, required: true],
      refactored_code: [type: :string, required: true],
      changed_regions: [type: {:list, :string}, required: true],
      warnings: [type: {:list, :string}, required: true]
    ]
  end
end
