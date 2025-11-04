defmodule ReqLLM.Providers.VLLM do
  @moduledoc """
  VLLM – fully OpenAI-compatible Chat Completions API.
  """

  @behaviour ReqLLM.Provider

  use ReqLLM.Provider.DSL,
    id: :vllm,
    base_url: "http://localhost:8000/v1",
    metadata: "priv/models_dev/vllm.json",
    default_env_key: "OPENAI_API_KEY",
    # built-in OpenAI-style encoding/decoding is used automatically
    provider_schema: [
      # Only list options that **do not** exist in the OpenAI spec
      # organisation_id: [type: :string, doc: "Optional tenant id"]
      default_path: [type: :string, doc: "default portion of url after the host and port"]
    ]

  defp select_api_mod(%ReqLLM.Model{} = model) do
    api_type = get_in(model, [Access.key(:_metadata, %{}), "api"])

    case api_type do
      "chat" -> ReqLLM.Providers.OpenAI.ChatAPI
      "responses" -> ReqLLM.Providers.OpenAI.ResponsesAPI
      _ -> ReqLLM.Providers.OpenAI.ChatAPI
    end
  end

  @impl ReqLLM.Provider
  @doc """
  Custom prepare_request to route reasoning models to /v1/responses endpoint.

  - :chat operations detect model type and route to appropriate endpoint
  - :object operations maintain OpenAI-specific token handling
  """
  def prepare_request(:chat, model_spec, prompt, opts) do
    with {:ok, model} <- ReqLLM.Model.from(model_spec),
         {:ok, context} <- ReqLLM.Context.normalize(prompt, opts),
         opts_with_context = Keyword.put(opts, :context, context),
         http_opts = Keyword.get(opts, :req_http_options, []),
         {:ok, provider_opts} <-
           ReqLLM.Provider.Options.process(__MODULE__, :chat, model, opts_with_context) do
      processed_opts = override_provider_opts_with_model_opts(provider_opts, model)

      api_mod = select_api_mod(model)
      path = api_mod.path()

      req_keys =
        supported_provider_options() ++
          [
            :context,
            :operation,
            :text,
            :stream,
            :model,
            :provider_options,
            :api_mod
          ]

      request =
        Req.new(
          [
            url: path,
            method: :post,
            receive_timeout: Keyword.get(processed_opts, :receive_timeout, 30_000)
          ] ++ http_opts
        )
        |> Req.Request.register_options(req_keys)
        |> Req.Request.merge_options(
          Keyword.take(processed_opts, req_keys) ++
            [
              model: model.model,
              base_url: Keyword.get(processed_opts, :base_url, default_base_url()),
              api_mod: api_mod
            ]
        )
        |> attach(model, processed_opts)

      {:ok, request}
    end
  end

  def prepare_request(operation, model_spec, input, opts) do
    case ReqLLM.Provider.Defaults.prepare_request(__MODULE__, operation, model_spec, input, opts) do
      {:error, %ReqLLM.Error.Invalid.Parameter{parameter: param}} ->
        {:error, ReqLLM.Error.Invalid.Parameter.exception(parameter: param)}

      result ->
        result
    end
  end

  defp override_provider_opts_with_model_opts(provider_opts, model) do
    provider_opts
    |> Keyword.put(:base_url, model.model_base_url)
  end
end
