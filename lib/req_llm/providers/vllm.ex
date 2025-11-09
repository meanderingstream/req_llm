defmodule ReqLLM.Providers.VLLM do
  @moduledoc """
  VLLM – fully OpenAI-compatible Chat Completions API.

  The OPENAI_API_KEY is required but the contents can be ignored when starting the vLLM service.

  ## Configuration

      # Add to .env file (automatically loaded)
      OPENAI_API_KEY=some_value...
  """

  @behaviour ReqLLM.Provider

  use ReqLLM.Provider.DSL,
    id: :vllm,
    # Required to have a value, but generally not used.
    base_url: "http://localhost:8005/v1",
    metadata: "priv/models_dev/vllm.json",
    default_env_key: "OPENAI_API_KEY",
    provider_schema: []
end
